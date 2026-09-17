defmodule TypeSafeSDK.SystemOneResponseTest do
  use ExUnit.Case, async: true

  alias TypeSafeSDK.{ChoiceAnswer, NoulAnswer, ScoreAnswer, SystemOneResponse}

  test "decodes all supported answer kinds and integer score keys" do
    body = %{
      "model" => "jev-latest",
      "usage" => %{"input_tokens" => 12, "output_tokens" => 4},
      "answers" => %{
        "billing" => %{"type" => "noul", "noul" => 0.97},
        "tone" => %{
          "type" => "choice",
          "choice" => "angry",
          "confidence" => 0.8,
          "probabilities" => %{"calm" => 0.2, "angry" => 0.8}
        },
        "urgency" => %{
          "type" => "score",
          "score" => 1.4,
          "confidence" => 0.7,
          "legend" => %{"0" => "low", "1" => "medium", "2" => "high"},
          "probabilities" => %{"0" => 0.1, "1" => 0.4, "2" => 0.5}
        }
      }
    }

    assert {:ok, response} = SystemOneResponse.decode(body)
    assert %NoulAnswer{noul: 0.97} = response.answers["billing"]
    assert %ChoiceAnswer{choice: "angry"} = response.answers["tone"]

    assert %ScoreAnswer{legend: %{0 => "low", 1 => "medium", 2 => "high"}} =
             response.answers["urgency"]

    assert Map.keys(SystemOneResponse.nouls(response)) == ["billing"]
    assert Map.keys(SystemOneResponse.choices(response)) == ["tone"]
    assert Map.keys(SystemOneResponse.scores(response)) == ["urgency"]
  end

  @tag capture_log: true
  test "ignores unknown future answer types without dropping known answers" do
    body = %{
      "model" => "jev-latest",
      "usage" => %{},
      "answers" => %{
        "known" => %{"type" => "noul", "noul" => 0.5},
        "future" => %{"type" => "future", "payload" => true}
      }
    }

    assert {:ok, response} = SystemOneResponse.decode(body)
    assert Map.has_key?(response.answers, "known")
    refute Map.has_key?(response.answers, "future")
  end

  test "attaches request id and raw Pristine response metadata" do
    body = %{
      "model" => "jev-latest",
      "usage" => %{},
      "answers" => %{"known" => %{"type" => "noul", "noul" => 0.5}}
    }

    raw = %Pristine.Response{
      status: 200,
      headers: %{"x-typesafe-request-id" => "req-42"},
      body: Jason.encode!(body),
      metadata: %{method: :post, url: "https://api.typesafe.ai/v1/systemone"}
    }

    wrapped = %TypeSafeSDK.TransportResponse{
      data: body,
      raw_http_response: raw,
      request_id: "req-42"
    }

    assert {:ok, response} = SystemOneResponse.decode(wrapped)
    assert response.request_id == "req-42"
    assert SystemOneResponse.request_id!(response) == "req-42"
    assert SystemOneResponse.raw_http_response!(response) == raw
  end

  test "returns a response-validation error with a precise field path" do
    body = %{
      "model" => "jev-latest",
      "usage" => %{},
      "answers" => %{
        "tone" => %{
          "type" => "choice",
          "choice" => "x",
          "confidence" => "bad",
          "probabilities" => %{}
        }
      }
    }

    assert {:error, %TypeSafeSDK.Error{type: :response_validation, field_path: path}} =
             SystemOneResponse.decode(body)

    assert path == "answers.tone.confidence"
  end
end
