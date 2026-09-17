defmodule TypeSafeSDK.SemanticTelemetryTest do
  use ExUnit.Case, async: true
  alias TypeSafeSDK.{Telemetry, Test}

  def handle_event(event, measurements, metadata, pid) do
    if metadata[:caller] == %{test: pid}, do: send(pid, {event, measurements, metadata})
  end

  setup do
    id = {__MODULE__, make_ref()}

    events =
      Enum.map([:start, :stop, :exception], &[:typesafe_sdk, :evaluate, &1]) ++
        [[:typesafe_sdk, :answer]]

    :ok =
      :telemetry.attach_many(
        id,
        events,
        &__MODULE__.handle_event/4,
        self()
      )

    on_exit(fn -> :telemetry.detach(id) end)
    %{metadata: %{test: self()}}
  end

  test "one semantic span has safe metadata, nested caller context and real token counts", %{
    metadata: caller
  } do
    client =
      Test.client() |> Test.stub([q: {:noul, 0.8}], usage: %{input_tokens: 3, output_tokens: 1})

    assert {:ok, _} =
             TypeSafeSDK.evaluate(
               client,
               "private-state",
               [q: TypeSafeSDK.noul("private-question")],
               telemetry_metadata: caller
             )

    assert_receive {[:typesafe_sdk, :evaluate, :start], _, start}
    assert_receive {[:typesafe_sdk, :answer], answer_measurements, answer_metadata}
    assert_receive {[:typesafe_sdk, :evaluate, :stop], measurements, stop}
    assert start.question_count == 1
    assert start.telemetry_span_context == stop.telemetry_span_context
    assert stop.outcome == :ok
    assert stop.status == 200
    assert measurements.input_tokens == 3
    assert measurements.duration >= 0
    assert answer_metadata.answer_type == :noul
    assert answer_metadata.question_index == 0
    assert answer_metadata.prepared_fingerprint =~ "typesafe-prepared-v1:"
    assert answer_measurements.confidence == 0.8
    assert answer_measurements.top_probability == 0.8
    assert_in_delta answer_measurements.distribution_margin, 0.6, 1.0e-12
    refute inspect({start, answer_metadata, stop}) =~ "private-state"
    refute inspect({start, answer_metadata, stop}) =~ "private-question"
    refute inspect({start, answer_metadata, stop}) =~ "typesafe-test-key"
    refute Map.has_key?(stop, :error)
  end

  test "per-answer events expose distribution shape but not answer values or question IDs", %{
    metadata: caller
  } do
    client =
      Test.client()
      |> Test.stub(
        [
          private_route:
            {:choice, :billing, probabilities: %{billing: 0.7, support: 0.3}, confidence: 0.4},
          private_score:
            {:score, 1.2, probabilities: %{0 => 0.1, 1 => 0.6, 2 => 0.3}, confidence: 0.5}
        ],
        model: "jev-fixture"
      )

    questions =
      TypeSafeSDK.prepare!(
        private_route: TypeSafeSDK.choice("secret route", billing: nil, support: nil),
        private_score: TypeSafeSDK.score("secret score", ["low", "medium", "high"])
      )

    assert {:ok, _} =
             TypeSafeSDK.evaluate(client, "secret state", questions, telemetry_metadata: caller)

    assert_receive {[:typesafe_sdk, :answer], choice, %{answer_type: :choice} = choice_meta}
    assert_receive {[:typesafe_sdk, :answer], score, %{answer_type: :score} = score_meta}

    assert choice.top_probability == 0.7
    assert_in_delta choice.distribution_margin, 0.4, 1.0e-12
    assert score.top_probability == 0.6
    assert_in_delta score.distribution_margin, 0.3, 1.0e-12
    assert choice_meta.question_index == 0
    assert score_meta.question_index == 1

    inspected = inspect({choice, choice_meta, score, score_meta})
    refute inspected =~ "billing"
    refute inspected =~ "private_route"
    refute inspected =~ "private_score"
    refute inspected =~ "secret route"
    refute inspected =~ "secret score"
    refute inspected =~ "secret state"
  end

  test "invalid local input has a terminal classified event", %{metadata: caller} do
    client = Test.client()

    assert {:error, _} =
             TypeSafeSDK.evaluate(client, self(), [q: TypeSafeSDK.noul("Q?")],
               telemetry_metadata: caller
             )

    assert_receive {[:typesafe_sdk, :evaluate, :stop], _, %{error_type: :invalid_request}}
    assert Test.requests(client) == []
  end

  @tag :capture_log
  test "future answers emit no answer event and known events keep Prepared order", %{
    metadata: caller
  } do
    client =
      Test.client()
      |> Test.stub_response(%{
        "model" => "test",
        "usage" => %{},
        "answers" => %{
          "future" => %{"type" => "future-type", "payload" => "private"},
          "known" => %{"type" => "noul", "noul" => 0.8}
        }
      })

    assert {:ok, response} =
             TypeSafeSDK.evaluate(
               client,
               "state",
               [future: TypeSafeSDK.noul("Future?"), known: TypeSafeSDK.noul("Known?")],
               telemetry_metadata: caller
             )

    assert TypeSafeSDK.Response.values(response) == %{known: 0.8}
    assert_receive {start_event, _, _}
    assert start_event == [:typesafe_sdk, :evaluate, :start]
    assert_receive {answer_event, _, answer_metadata}
    assert answer_event == [:typesafe_sdk, :answer]
    assert answer_metadata.question_index == 1
    assert_receive {stop_event, _, _}
    assert stop_event == [:typesafe_sdk, :evaluate, :stop]
    refute_receive {[:typesafe_sdk, :answer], _, _}
  end

  test "exception event excludes reason and stacktrace while preserving the caller exception", %{
    metadata: caller
  } do
    assert_raise RuntimeError, "private-exception", fn ->
      Telemetry.span(%{caller: caller}, fn -> raise "private-exception" end)
    end

    assert_receive {[:typesafe_sdk, :evaluate, :exception], _, metadata}
    assert metadata.kind == :error
    refute Map.has_key?(metadata, :reason)
    refute Map.has_key?(metadata, :stacktrace)
    refute inspect(metadata) =~ "private-exception"
  end
end
