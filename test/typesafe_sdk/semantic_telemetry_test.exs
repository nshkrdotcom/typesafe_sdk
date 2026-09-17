defmodule TypeSafeSDK.SemanticTelemetryTest do
  use ExUnit.Case, async: true
  alias TypeSafeSDK.{Telemetry, Test}

  setup do
    id = {__MODULE__, make_ref()}
    events = Enum.map([:start, :stop, :exception], &[:typesafe_sdk, :evaluate, &1])
    :ok = :telemetry.attach_many(id, events, fn event, measurements, metadata, pid ->
      if metadata[:caller] == %{test: pid}, do: send(pid, {event, measurements, metadata})
    end, self())
    on_exit(fn -> :telemetry.detach(id) end)
    %{metadata: %{test: self()}}
  end

  test "one semantic span has safe metadata, nested caller context and real token counts", %{metadata: caller} do
    client = Test.client() |> Test.stub([q: {:noul, 0.8}], usage: %{input_tokens: 3, output_tokens: 1})
    assert {:ok, _} = TypeSafeSDK.evaluate(client, "private-state", [q: TypeSafeSDK.noul("private-question")], telemetry_metadata: caller)
    assert_receive {[:typesafe_sdk, :evaluate, :start], _, start}
    assert_receive {[:typesafe_sdk, :evaluate, :stop], measurements, stop}
    assert start.question_count == 1
    assert start.telemetry_span_context == stop.telemetry_span_context
    assert stop.outcome == :ok
    assert stop.status == 200
    assert measurements.input_tokens == 3
    assert measurements.duration >= 0
    refute inspect({start, stop}) =~ "private-state"
    refute inspect({start, stop}) =~ "private-question"
    refute inspect({start, stop}) =~ "typesafe-test-key"
    refute Map.has_key?(stop, :error)
  end

  test "invalid local input has a terminal classified event", %{metadata: caller} do
    client = Test.client()
    assert {:error, _} = TypeSafeSDK.evaluate(client, self(), [q: TypeSafeSDK.noul("Q?")], telemetry_metadata: caller)
    assert_receive {[:typesafe_sdk, :evaluate, :stop], _, %{error_type: :invalid_request}}
    assert Test.requests(client) == []
  end

  test "exception event excludes reason and stacktrace while preserving the caller exception", %{metadata: caller} do
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
