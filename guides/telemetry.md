# Privacy-Oriented Semantic Telemetry

`evaluate` emits `[:typesafe_sdk, :evaluate, :start | :stop | :exception]` above
Pristine's existing request/attempt telemetry. There is one semantic span per
call, including local validation, all runtime attempts and decoding.

```elixir
TypeSafeSDK.evaluate(client, state, questions,
  telemetry_metadata: %{job_id: "job-42", workflow: "triage"})
```

Caller metadata is nested under `:caller`, never merged into reserved fields.
Start metadata includes operation, requested model, question count and a span
reference. Successful stop metadata adds outcome, actual model, status, request
ID and retry count; token counts are measurements when present. Stop duration
uses native monotonic units; convert with `System.convert_time_unit/3`.
Failures are ordinary stop events with `error_type`, not raw errors. An error's
retry count is nil unless the underlying error actually supplies it.

No automatic event includes state, question content/IDs, bodies, headers,
authorization, exception reasons or stacktraces. Exception events include only
kind/outcome and safe span context, then re-raise the original exception to the
caller. The generic runtime and host telemetry handlers have their own privacy
contracts; this guarantee describes the SDK's semantic events, not every library
in the application. Caller-supplied metadata can still leak data: put IDs there,
not customer text or secrets.

The batch owner emits `[:typesafe_sdk, :batch, :cancelled]` for observed task
timeouts/exits with input index and classification, never raw exit reasons.
A process killed without executing cleanup cannot emit a guaranteed terminal
semantic span. Early-halt cleanup does not fabricate completion/cancellation
measurements for unobserved work, and no event proves remote cancellation.
