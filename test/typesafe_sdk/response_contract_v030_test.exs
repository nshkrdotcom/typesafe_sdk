defmodule TypeSafeSDK.ResponseContractV030Test do
  use ExUnit.Case, async: true

  alias TypeSafeSDK.{Error, Test}

  defp questions, do: [q: TypeSafeSDK.noul("Q?")]

  test "default preserves unknown future answer entries" do
    client = Test.client() |> Test.stub_response(%{
      "model" => "model-a",
      "usage" => %{},
      "answers" => %{
        "q" => %{"type" => "noul", "noul" => 0.9},
        "future" => %{"type" => "future", "value" => 1}
      }
    })

    assert {:ok, response} = TypeSafeSDK.evaluate(client, "state", questions())
    assert Map.has_key?(response.unknown_answers, "future")
  end

  test "strict unknown-answer policy fails closed with bounded metadata" do
    client = Test.client() |> Test.stub_response(%{
      "model" => "model-a",
      "usage" => %{},
      "answers" => %{
        "q" => %{"type" => "noul", "noul" => 0.9},
        "future" => %{"type" => "future", "value" => "secret-body-value"}
      }
    })

    assert {:error, %Error{type: :response_contract} = error} =
             TypeSafeSDK.evaluate(client, "state", questions(),
               response_contract: [on_unknown_answer: :error]
             )

    assert error.details.violation == :unknown_answer
    assert error.details.answer_key == "future"
    assert error.request_id == "req_typesafe_test"
    refute inspect(TypeSafeSDK.Error.metadata(error)) =~ "secret-body-value"
  end

  test "allowed_models uses exact membership and can be configured on the client" do
    client =
      Test.client(response_contract: [allowed_models: ["model-a"]])
      |> Test.stub(q: {:noul, 0.9}, model: "model-b")

    assert {:error, %Error{type: :response_contract, details: %{violation: :model_not_allowed}}} =
             TypeSafeSDK.evaluate(client, "state", questions())
  end

  test "per-call response contract keys merge over client defaults" do
    client =
      Test.client(response_contract: [on_unknown_answer: :error, allowed_models: ["model-a"]])
      |> Test.stub(q: {:noul, 0.9}, model: "model-b")

    assert {:ok, response} =
             TypeSafeSDK.evaluate(client, "state", questions(),
               response_contract: [allowed_models: ["model-b"]]
             )

    assert response.model == "model-b"
  end
end
