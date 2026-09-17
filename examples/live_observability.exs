Code.require_file("support/live.exs", __DIR__)
alias TypeSafeSDK.Examples.Live

# Exported handler avoids telemetry's anonymous-handler performance warning.
defmodule TypeSafeSDK.Examples.LiveTelemetry do
  def handle(event, measurements, metadata, owner) do
    if metadata[:caller] == %{example: "live-observability"} do
      send(owner, {:semantic_event, event, measurements, metadata})
    end
  end
end

client = Live.client()
id = {TypeSafeSDK.Examples.LiveTelemetry, make_ref()}
events =
  Enum.map([:start, :stop, :exception], &[:typesafe_sdk, :evaluate, &1]) ++
    [[:typesafe_sdk, :answer]]
:ok = :telemetry.attach_many(id, events, &TypeSafeSDK.Examples.LiveTelemetry.handle/4, self())

try do
  response =
    TypeSafeSDK.evaluate!(
      client,
      "Please send a copy of the invoice.",
      [billing: TypeSafeSDK.noul("Is this a billing request?")],
      telemetry_metadata: %{example: "live-observability"},
      extra_headers: %{"x-example-purpose" => "sdk-release-check"}
    )

  Live.show("Live response", Live.summary(response))

  for expected <- [
        [:typesafe_sdk, :evaluate, :start],
        [:typesafe_sdk, :answer],
        [:typesafe_sdk, :evaluate, :stop]
      ] do
    receive do
      {:semantic_event, ^expected = event, measurements, metadata} ->
        duration_ms =
          case measurements[:duration] do
            nil -> nil
            native -> System.convert_time_unit(native, :native, :microsecond) / 1000
          end

        Live.show("Semantic telemetry", %{
          event: event,
          measurements: measurements,
          duration_ms: duration_ms,
          metadata: metadata
        })
    after
      1_000 -> raise "Missing semantic #{inspect(expected)} event"
    end
  end
after
  :telemetry.detach(id)
end

report = TypeSafeSDK.RuntimeCapabilities.report(client)
Live.show("Actual transport capability advertisement", report)

Live.show(
  "Fail-closed check (an error is expected for unadvertised bounds)",
  TypeSafeSDK.RuntimeCapabilities.check(client, [:bounded_queue, :max_response_bytes])
)

# These local maintenance checks complement, rather than replace, the live call.
:ok = TypeSafeSDK.Schema.verify(Application.app_dir(:typesafe_sdk, "priv/json_schema"))
IO.puts("Committed wire schemas verified. No transport guarantee was inferred from a live success.")
