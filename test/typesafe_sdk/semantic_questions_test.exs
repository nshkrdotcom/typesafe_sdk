defmodule TypeSafeSDK.SemanticQuestionsTest do
  use ExUnit.Case, async: true

  alias TypeSafeSDK.{Error, JSON, Prepared, Question}
  alias TypeSafeSDK.Question.{Choice, Noul, Score}

  test "strict constructors have tuple and raising forms without changing legacy constructors" do
    assert {:ok, %Noul{}} = Noul.new("Urgent?", true: "Urgent", false: "Routine")
    assert %Noul{} = TypeSafeSDK.noul("Urgent?")
    assert %Choice{} = TypeSafeSDK.choice("Team?", billing: nil, technical: nil)
    assert %Score{} = TypeSafeSDK.score("Severity?", ["Low", "High"])
    assert %TypeSafeSDK.Choice{} = TypeSafeSDK.Choice.new(%{"only" => nil})
    assert %TypeSafeSDK.Score{} = TypeSafeSDK.Score.new(["only"])
    assert {:error, %Error{type: :invalid_request}} = Choice.new("Team?", only: nil)
    assert_raise Error, fn -> Score.new!("Severity?", ["only"]) end
  end

  test "choice pairs keep order including large maps and atoms restore only through finite keys" do
    criteria = for n <- 40..1//-1, do: {"option_#{n}", nil}
    question = Choice.new!("Pick", criteria)
    assert {:ok, %Prepared{} = prepared} = TypeSafeSDK.prepare(team: question)
    wire = Jason.encode!(prepared.encoded)
    assert :binary.match(wire, "option_40") < :binary.match(wire, "option_1\"")
    assert prepared.keys == %{"team" => :team}
    assert prepared.definitions["team"].option_keys["option_40"] == "option_40"

    map_question = Choice.new!("Pick", Map.new(criteria))
    assert Enum.map(map_question.criteria, &elem(&1, 0)) ==
             Enum.sort(Enum.map(criteria, &elem(&1, 0)))
  end

  test "normalized collisions are rejected before conversion to maps" do
    assert {:error, %Error{path: ["criteria", "billing"]}} =
             Choice.new("Team?", [{:billing, nil}, {"billing", nil}])

    q = TypeSafeSDK.noul("Question?")
    assert {:error, %Error{path: ["questions", "q"]}} =
             TypeSafeSDK.prepare([{:q, q}, {"q", q}])

    assert {:error, %Error{path: ["payload", "nested", "x"]}} =
             JSON.normalize(%{nested: %{:x => 1, "x" => 2}}, ["payload"])
  end

  test "count boundaries and Noul criteria are enforced" do
    for count <- [2, 255] do
      assert {:ok, _} = Choice.new("Pick", for(n <- 1..count, do: {"k#{n}", nil}))
    end

    assert {:error, _} = Choice.new("Pick", for(n <- 1..256, do: {"k#{n}", nil}))
    assert {:ok, _} = Score.new("Rate", Enum.map(1..10, &"Level #{&1}"))
    assert {:error, _} = Score.new("Rate", Enum.map(1..11, &"Level #{&1}"))
    assert {:error, _} = Noul.new("Yes?", criteria: %{maybe: "Maybe"})
    assert {:error, _} = Noul.new("Yes?", criteria: [{true, "yes"}, {"true", "yes"}])
    assert {:error, _} = Noul.new("Yes?", tru: "typo")
  end

  test "structured levels preserve labels and descriptions and extras cannot override fields" do
    q = Score.new!(%{question: "Rate"}, [{"Low", %{impact: "cosmetic"}}, "High"],
      extra: %{future: true})
    assert :ok = Question.validate(q)
    assert q == Question.validate!(q)
    assert {:ok, prepared} = TypeSafeSDK.prepare(severity: q)
    encoded = prepared.encoded |> Jason.encode!() |> Jason.decode!()
    assert encoded["severity"]["criteria"] == [
             %{"label" => "Low", "description" => %{"impact" => "cosmetic"}}, "High"]
    assert encoded["severity"]["future"]
    assert {:error, %Error{path: ["extra", "type"]}} =
             Noul.new("Yes?", extra: %{type: "future"})
    assert {:error, _} = Choice.new("Team", [a: nil, b: nil], extra: %{"criteria" => %{}})
  end

  test "invalid JSON returns path-aware errors without atomizing incoming data" do
    for value <- [self(), fn -> :ok end, {:tuple, 1}, :not_json, ~D[2026-09-16], <<255>>] do
      assert {:error, %Error{type: :invalid_request}} = JSON.normalize(%{x: value}, ["state"])
    end

    nested = Enum.reduce(1..70, nil, fn _, acc -> [acc] end)
    assert {:error, _} = JSON.normalize(nested)
    assert {:ok, %{"x" => false, "n" => nil}} = JSON.normalize(%{x: false, n: nil})
  end

  test "raw future questions remain forward compatible and Prepared is reusable" do
    assert {:ok, p} = TypeSafeSDK.prepare(%{"future" => %{
             type: "future", instructions: "Next", future_parameter: true}})
    assert {:ok, ^p} = TypeSafeSDK.prepare(p)
    assert p.definitions["future"].type == "future"
    assert {:error, _} = TypeSafeSDK.prepare(%{})
    assert {:error, _} = TypeSafeSDK.prepare(%{" " => TypeSafeSDK.noul("Yes?")})
  end
  test "improper JSON arrays, pair lists and level lists return validation tuples" do
    assert {:error, %Error{type: :invalid_request}} = JSON.normalize([1 | :invalid])
    assert {:error, %Error{type: :invalid_request}} =
      TypeSafeSDK.prepare([{:q, TypeSafeSDK.noul("Q?")} | :invalid])
    assert {:error, %Error{type: :invalid_request}} = Score.new("Rate", ["Low" | :invalid])
  end

end
