Code.require_file("support/live.exs", __DIR__)

alias TypeSafeSDK.Examples.Live
alias TypeSafeSDK.{Response, RuntimeCapabilities}

# Exported handler avoids telemetry's anonymous-handler performance warning.
defmodule TypeSafeSDK.Examples.LiveTelemetry do
  def handle(event, measurements, metadata, owner) do
    case metadata[:caller] do
      %{example: "live-observability"} ->
        send(owner, {:semantic_event, event, measurements, metadata})

      _ ->
        :ok
    end
  end
end

client = Live.client()
Live.show_configuration(client)
id = {TypeSafeSDK.Examples.LiveTelemetry, make_ref()}

events =
  Enum.map([:start, :stop, :exception], &[:typesafe_sdk, :evaluate, &1]) ++
    [[:typesafe_sdk, :answer]]

:ok = :telemetry.attach_many(id, events, &TypeSafeSDK.Examples.LiveTelemetry.handle/4, self())

caller_metadata = %{
  example: "live-observability",
  trace: %{workflow: "synthetic-triage", sample: 1},
  release: "0.4.0"
}

prepared =
  TypeSafeSDK.prepare!(
    billing: TypeSafeSDK.noul("Is this primarily a billing request?"),
    team:
      TypeSafeSDK.choice("Which team owns this?", [
        {:billing, "Billing"},
        {:technical, "Technical"},
        {:sales, "Sales"}
      ]),
    severity: TypeSafeSDK.score("How severe is the impact?", ["Low", "Medium", "High"])
  )

try do
  response =
    TypeSafeSDK.evaluate!(
      client,
      "A duplicate charge appeared while checkout was unavailable.",
      prepared,
      telemetry_metadata: caller_metadata,
      extra_headers: %{"x-example-purpose" => "sdk-release-check"},
      retry: false
    )

  Live.show("Live response", %{
    values: Response.values(response),
    metadata: Response.metadata(response)
  })

  expected = [
    {[:typesafe_sdk, :evaluate, :start], nil, nil},
    {[:typesafe_sdk, :answer], :noul, 0},
    {[:typesafe_sdk, :answer], :choice, 1},
    {[:typesafe_sdk, :answer], :score, 2},
    {[:typesafe_sdk, :evaluate, :stop], nil, nil}
  ]

  observed =
    Enum.map(expected, fn {expected_event, expected_type, expected_index} ->
      receive do
        {:semantic_event, ^expected_event = event, measurements, metadata} ->
          if expected_type do
            unless metadata.answer_type == expected_type and
                     metadata.question_index == expected_index do
              raise "Unexpected per-answer telemetry ordering: #{inspect(metadata)}"
            end
          end

          automatic = Map.delete(metadata, :caller)

          forbidden = [
            :state,
            :questions,
            :question,
            :question_id,
            :answer,
            :selected_label,
            :score_value,
            :noul_direction,
            :headers,
            :api_key,
            :raw,
            :error,
            :reason,
            :stacktrace,
            :tag
          ]

          leaked_keys = Enum.filter(forbidden, &Map.has_key?(automatic, &1))
          if leaked_keys != [], do: raise("Automatic telemetry exposed forbidden keys: #{inspect(leaked_keys)}")

          duration_ms =
            case measurements[:duration] do
              nil -> nil
              native -> System.convert_time_unit(native, :native, :microsecond) / 1000
            end

          %{
            event: event,
            answer_type: metadata[:answer_type],
            question_index: metadata[:question_index],
            measurements: measurements,
            duration_ms: duration_ms,
            automatic_metadata: automatic,
            caller_metadata: metadata[:caller]
          }
      after
        1_000 -> raise "Missing semantic #{inspect(expected_event)} event"
      end
    end)

  Live.show("Semantic telemetry in emitted order", observed)

  unless Enum.map(observed, & &1.event) == Enum.map(expected, &elem(&1, 0)) do
    raise "Semantic telemetry was not emitted in start -> answers -> stop order"
  end

after
  :telemetry.detach(id)
end

report = RuntimeCapabilities.report(client)
Live.show("Actual transport capability advertisement", report)

Live.show(
  "Fail-closed check (an error is expected for unadvertised bounds)",
  RuntimeCapabilities.check(client, [:bounded_queue, :max_response_bytes])
)

# This local maintenance check complements, rather than replaces, the live call.
:ok = TypeSafeSDK.Schema.verify(Application.app_dir(:typesafe_sdk, "priv/json_schema"))

IO.puts("""
All three known answer families emitted one answer event in Prepared order. Explicit caller metadata
remains nested under :caller. Automatic semantic telemetry carries distribution shape and bounded
identifiers only; it does not automatically add question/answer/tag secrets, raw errors, or stacktraces.
Committed wire schemas were also checked locally; that is not evidence of transport behavior.
""")
