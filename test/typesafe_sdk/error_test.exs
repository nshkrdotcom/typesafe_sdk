defmodule TypeSafeSDK.ErrorTest do
  use ExUnit.Case, async: true

  alias Pristine.Core.Response
  alias TypeSafeSDK.Error

  test "extracts server messages with Python SDK precedence" do
    assert Error.extract_message(%{"error" => "e", "message" => "m"}) == "e"
    assert Error.extract_message(%{"error" => %{"message" => "nested"}}) == "nested"
    assert Error.extract_message(%{"message" => "m"}) == "m"
    assert Error.extract_message(%{"detail" => %{"message" => "d"}}) == "d"

    assert Error.extract_message(%{
             "detail" => [
               %{"loc" => ["body", "questions", "q", "criteria", 0], "msg" => "Invalid"},
               %{"msg" => "Missing"}
             ]
           }) == "questions.q.criteria.0: Invalid; Missing"
  end

  test "maps HTTP status and request metadata" do
    response = %Response{
      status: 429,
      headers: %{"x-typesafe-request-id" => "req_123", "retry-after-ms" => "125"},
      metadata: %{method: :get, url: "https://api.typesafe.ai/v1/models?secret=removed"}
    }

    error =
      Error.from_response(response, %{"detail" => "Slow down"}, nil,
        profile: TypeSafeSDK.ProviderProfile.profile()
      )

    assert error.type == :rate_limit
    assert error.request_id == "req_123"
    assert error.retry_after_ms == 125

    assert error.message ==
             "GET https://api.typesafe.ai/v1/models: 429 Slow down (request_id=req_123)"
  end
end
