Code.require_file("../../examples/support/live.exs", __DIR__)

defmodule TypeSafeSDK.LiveTest do
  use ExUnit.Case

  @moduletag :live

  alias TypeSafeSDK.{Choice, Score}
  alias TypeSafeSDK.Examples.Live

  setup do
    case System.get_env("TYPESAFE_API_KEY") do
      key when is_binary(key) and byte_size(key) > 0 ->
        {:ok, client: Live.client()}

      _ ->
        flunk("TYPESAFE_API_KEY is required when live tests are enabled")
    end
  end

  test "lists real models", %{client: client} do
    assert {:ok, response} = TypeSafeSDK.list_models(client)
    assert response.models != []
    assert Enum.all?(response.models, &is_binary(&1.name))
  end

  test "runs real System One questions", %{client: client} do
    questions = %{
      "billing" => %{"type" => "noul", "instructions" => "Is this ticket about billing?"},
      "tone" =>
        Choice.new(
          %{"calm" => nil, "frustrated" => nil, "angry" => nil},
          instructions: "What is the customer's tone?"
        ),
      "urgency" =>
        Score.new(["can wait", "this week", "today"], instructions: "How urgent is this ticket?")
    }

    state = %{
      "subject" => "Charged twice",
      "body" => "I see two charges of $49. Please fix this ASAP."
    }

    assert {:ok, response} = TypeSafeSDK.system_one(client, state, questions)
    assert response.model != ""
    assert Map.has_key?(response.answers, "billing")
    assert Map.has_key?(response.answers, "tone")
    assert Map.has_key?(response.answers, "urgency")
  end
end
