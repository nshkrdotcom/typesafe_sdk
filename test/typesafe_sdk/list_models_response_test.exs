defmodule TypeSafeSDK.ListModelsResponseTest do
  use ExUnit.Case, async: true

  alias TypeSafeSDK.ListModelsResponse

  test "decodes models and ignores unknown fields" do
    body = %{
      "models" => [
        %{
          "name" => "jev-latest",
          "description" => "Jev",
          "release_date" => "2026-09-01",
          "future_field" => 123
        }
      ]
    }

    assert {:ok, %ListModelsResponse{models: [model]}} = ListModelsResponse.decode(body)
    assert model.name == "jev-latest"
    assert model.description == "Jev"
    assert model.release_date == "2026-09-01"
  end

  test "attaches metadata and validation context from a wrapped response" do
    body = %{"models" => [%{"name" => "test"}]}

    raw = %Pristine.Response{
      status: 200,
      headers: %{"x-typesafe-request-id" => "req-models"},
      body: Jason.encode!(body),
      metadata: %{method: :get, url: "https://api.typesafe.ai/v1/models"}
    }

    wrapped = %TypeSafeSDK.TransportResponse{
      data: body,
      raw_http_response: raw,
      request_id: "req-models"
    }

    assert {:error, %TypeSafeSDK.Error{} = error} = ListModelsResponse.decode(wrapped)
    assert error.status == 200
    assert error.request_id == "req-models"
    assert error.field_path == "models[0].description"
    assert error.body == body
    assert error.raw_http_response == raw
  end

  test "rejects missing required model metadata" do
    assert {:error, %TypeSafeSDK.Error{field_path: "models[0].description"}} =
             ListModelsResponse.decode(%{"models" => [%{"name" => "x"}]})
  end
end
