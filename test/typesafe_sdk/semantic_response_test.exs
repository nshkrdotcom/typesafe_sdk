defmodule TypeSafeSDK.SemanticResponseTest do
  use ExUnit.Case, async: true
  alias TypeSafeSDK.{Answer, Error, Response, SemanticResponse, SystemOneResponse}

  defp questions do
    TypeSafeSDK.prepare!(
      urgent: TypeSafeSDK.noul("Urgent?"),
      team: TypeSafeSDK.choice("Team?", billing: "Payments", support: "Product"),
      level: TypeSafeSDK.score("Severity?", [{"Low", "Cosmetic"}, {"High", "Blocking"}])
    )
  end

  defp body do
    %{
      "model" => "jev-test",
      "usage" => %{"input_tokens" => 3, "output_tokens" => 2},
      "answers" => %{
        "urgent" => %{"type" => "noul", "noul" => 0.9},
        "team" => %{
          "type" => "choice",
          "choice" => "billing",
          "confidence" => 0.4,
          "probabilities" => %{"billing" => 0.8, "support" => 0.2}
        },
        "level" => %{
          "type" => "score",
          "score" => 0.7,
          "confidence" => 0.8,
          "legend" => %{"0" => "server-low", "1" => "server-high"},
          "probabilities" => %{"0" => 0.3, "1" => 0.7}
        }
      }
    }
  end

  defp decode(body) do
    with {:ok, response} <- SystemOneResponse.decode(body),
         do: SemanticResponse.enrich(response, questions(), 0.02)
  end

  test "one response type retains wire data, restores keys and joins the original rubric" do
    raw = body()
    assert {:ok, response} = decode(raw)
    assert response.raw == raw
    assert response.answers.team.choice == :billing
    assert response.answers.team.raw == raw["answers"]["team"]
    assert response.answers.level.label == "High"
    assert response.answers.level.description == "Blocking"
    assert response.answers.level.legend[1] == "server-high"
    assert response.answers.level.levels == [{"Low", 0.3}, {"High", 0.7}]
    assert {:ok, _} = Response.fetch(response, :team)
    assert :error = Response.fetch(response, "team")
    assert_raise KeyError, ~r/available IDs/, fn -> Response.fetch!(response, "team") end
    assert Map.keys(Response.choices(response)) == [:team]
    assert Map.keys(Response.nouls(response)) == [:urgent]
    assert Map.keys(Response.scores(response)) == [:level]
    assert Response.values(response) == %{urgent: 0.9, team: :billing, level: 0.7}
  end

  test "malformed known relational contracts fail with specific paths" do
    cases = [
      {["answers", "team", "choice"], "unknown"},
      {["answers", "team", "probabilities"], %{"billing" => 1.0}},
      {["answers", "team", "probabilities"], %{"billing" => 0.1, "support" => 0.1}},
      {["answers", "level", "score"], 2.0},
      {["answers", "level", "legend"], %{"0" => "low", "2" => "high"}},
      {["answers", "level", "probabilities"], %{"0" => 0.2, "2" => 0.8}}
    ]

    for {path, value} <- cases do
      invalid = put_in(body(), path, value)
      assert {:error, %Error{type: :response_validation, path: ^path}} = decode(invalid)
    end
  end

  test "known missing, extra and wrong-type answers are not silently accepted" do
    assert {:error, %Error{path: ["answers", "team"]}} =
             decode(update_in(body()["answers"], &Map.delete(&1, "team")))

    assert {:error, %Error{path: ["answers", "extra"]}} =
             decode(put_in(body(), ["answers", "extra"], %{"type" => "noul", "noul" => 1}))

    assert {:error, %Error{path: ["answers", "team", "type"]}} =
             decode(put_in(body(), ["answers", "team"], %{"type" => "noul", "noul" => 1}))
  end

  @tag capture_log: true
  test "unknown future answers remain raw and do not fail known-answer completeness" do
    raw =
      body()
      |> put_in(["answers", "team"], %{"type" => "future", "payload" => true})
      |> put_in(["answers", "future-id"], %{"type" => "future", "payload" => true})

    assert {:ok, response} = decode(raw)
    refute Map.has_key?(response.answers, :team)
    assert response.unknown_answers["team"]["type"] == "future"
    assert response.raw == raw
  end

  test "wire scalars reject out-of-range probabilities and negative usage" do
    for {path, value} <- [
          {["answers", "urgent", "noul"], -0.1},
          {["answers", "team", "confidence"], 1.1},
          {["answers", "team", "probabilities"], %{"billing" => -0.1, "support" => 1.1}},
          {["answers", "level", "probabilities"], %{"0" => -0.1, "1" => 1.1}},
          {["usage", "input_tokens"], -1},
          {["usage", "output_tokens"], 0.5}
        ] do
      assert {:error, %Error{type: :response_validation}} =
               SystemOneResponse.decode(put_in(body(), path, value))
    end
  end

  test "normalizing numeric distribution keys cannot overwrite colliding entries" do
    invalid =
      put_in(body(), ["answers", "level", "probabilities"], %{"0" => 0.2, "00" => 0.1, "1" => 0.7})

    assert {:error, %Error{field_path: "answers.level.probabilities"}} =
             SystemOneResponse.decode(invalid)
  end

  test "tolerance is explicit and does not renormalize the recorded distribution" do
    raw = put_in(body(), ["answers", "team", "probabilities", "billing"], 0.79)
    {:ok, wire} = SystemOneResponse.decode(raw)
    assert {:ok, response} = SemanticResponse.enrich(wire, questions(), 0.02)
    assert response.answers.team.probabilities.billing == 0.79
    assert {:error, _} = SemanticResponse.enrich(wire, questions(), 0.0)
  end

  test "Noul certainty and decision gates require explicit valid application policy" do
    {:ok, response} = decode(body())
    assert Answer.yes?(response.answers.urgent, 0.85)
    refute Answer.yes?(response.answers.urgent, 0.95)
    assert Answer.confidence(response.answers.urgent) == 0.9
    assert Answer.confidence(response.answers.team) == 0.4
    assert Answer.gate(response.answers.team, act: 0.9, review: 0.4) == :review
    assert Answer.gate(response.answers.team, act: 0.9, review: 0.6) == :escalate
    assert Answer.gate(response.answers.urgent, act: 0.9, review: 0.6) == :act

    for opts <- [[], [act: 0.9], [act: 0.2, review: 0.9], [act: 1.1, review: 0.5]] do
      assert_raise ArgumentError, fn -> Answer.gate(response.answers.team, opts) end
    end
  end

  test "Choice ranking uses explicit caller tie order and margin is not confidence" do
    answer = %TypeSafeSDK.ChoiceAnswer{
      choice: :z,
      confidence: 0.9,
      probabilities: %{a: 0.5, z: 0.5},
      option_order: [:z, :a]
    }

    assert Answer.Choice.ranked(answer) == [z: 0.5, a: 0.5]
    assert Answer.Choice.margin(answer) == 0.0
  end

  test "rounded expectation can be the least likely level" do
    answer = %TypeSafeSDK.ScoreAnswer{
      score: 1.0,
      confidence: 0.4,
      legend: %{0 => "Low", 1 => "Middle", 2 => "High"},
      probabilities: %{0 => 0.45, 1 => 0.1, 2 => 0.45}
    }

    assert Answer.Score.expected_level(answer) == {1, "Middle"}
    assert Answer.Score.max_level(answer) == {0, "Low"}
    assert Answer.Score.ranked(answer) == [{0, 0.45}, {2, 0.45}, {1, 0.1}]
    assert Answer.Score.normalized(answer) == 0.5
  end

  test "wire validation paths preserve IDs that contain dots" do
    body = %{
      "model" => "jev",
      "usage" => %{},
      "answers" => %{
        "name.with.dots" => %{"type" => "noul", "noul" => 2}
      }
    }

    assert {:error, %Error{path: ["answers", "name.with.dots", "noul"]}} =
             SystemOneResponse.decode(body)
  end

  @tag capture_log: true
  test "unknown response names and type tags are not interned as atoms" do
    id = "future-id-#{System.unique_integer([:positive])}"
    tag = "future-tag-#{System.unique_integer([:positive])}"

    body = %{
      "model" => "jev",
      "usage" => %{},
      "answers" => %{
        id => %{"type" => tag, "payload" => "kept raw"}
      }
    }

    assert {:ok, response} = SystemOneResponse.decode(body)
    assert response.unknown_answers[id]["type"] == tag
    assert_raise ArgumentError, fn -> String.to_existing_atom(id) end
    assert_raise ArgumentError, fn -> String.to_existing_atom(tag) end
  end
end
