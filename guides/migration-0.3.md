# Migrating from 0.2.x to 0.3.0

TypeSafe SDK 0.3.0 keeps the 0.2 semantic defaults and moves no HTTP/runtime
responsibility into TypeSafe. The required runtime is now Pristine `~> 0.4.0`.

```elixir
{:typesafe_sdk, "~> 0.3.0"}
```

## What remains compatible

Existing `evaluate/4`, `system_one/4`, semantic question constructors, enriched
answers, test fixtures, batch options, telemetry, schema tooling and raw/wire
escape hatches keep their 0.2 behavior unless a new 0.3 option is supplied.
Strict response contracts and request-byte budgets are opt-in.

## Cancellation

Use Pristine's token directly; TypeSafe does not define a second cancellation
object:

```elixir
cancel = Pristine.Cancellation.new()

request =
  Task.async(fn ->
    TypeSafeSDK.evaluate(client, state, prepared, cancellation: cancel)
  end)

:ok = Pristine.Cancellation.cancel(cancel)
Task.await(request)
```

A supported Pristine transport physically terminates the verified local unary
HTTP operation and cleans up its local execution resources. Cancellation does
**not** prove the remote service never received or began processing the request,
and it does not roll back remote side effects. Therefore a caller must treat a
cancelled mutating/replay-sensitive operation as outcome-ambiguous unless the
remote API itself provides idempotency or reconciliation semantics.

Inspect the configured transport without sending a request:

```elixir
report = TypeSafeSDK.RuntimeCapabilities.report(client)
report.runtime.unary_cancellation
# => %{status: :supported} | %{status: :unsupported} | %{status: :unverified}
```

Capability discovery delegates to `Pristine.RuntimeCapabilities.transport/1`
and fails closed. TypeSafe does not infer support from an adapter name or
`function_exported?/3`.

## Batch cancellation

A `cancellation:` token passed to `evaluate_many/4` or `evaluate_stream/4` is
shared by all started unary evaluations. The scheduler checks the token before
starting additional items. Once cancellation is observed, no new request work is
scheduled; already-completed results remain valid and in-flight cancellation
uses the normal TypeSafe error/result conventions. Existing owned supervisors,
tasks and monitors are cleaned up on completion, cancellation or early halt.

## Retry inheritance

Client retry options are defaults. Per-call options now merge rather than
replacing the whole policy:

```elixir
client = TypeSafeSDK.new_client(
  api_key: key,
  retry: [max_retries: 4, backoff_max: 8.0]
)

# Inherits backoff_max: 8.0 and every other client field.
TypeSafeSDK.evaluate(client, state, prepared, retry: [max_retries: 1])

# Explicitly disable for this call.
TypeSafeSDK.evaluate(client, state, prepared, retry: false)
```

TypeSafe only resolves configuration. Pristine still owns retry execution,
classification, retry waits and cancellation during those waits.

## Prepared composition and fingerprints

```elixir
prepared = TypeSafeSDK.prepare!(
  urgent: TypeSafeSDK.noul("Urgent?"),
  team: TypeSafeSDK.choice("Team?", billing: "Billing", product: "Product")
)

TypeSafeSDK.Prepared.keys(prepared)
# => [:urgent, :team]

{:ok, updated} =
  TypeSafeSDK.Prepared.put(prepared, :severity, TypeSafeSDK.score("Severity?", ["Low", "High"]))

TypeSafeSDK.Prepared.fingerprint(updated)
# => "typesafe-prepared-v1:<sha256>"
```

`put/3` replaces in place or appends; `delete/2` removes only the selected key;
`take/2` keeps source order; `merge/2` is right-biased while preserving duplicate
positions from the left and appending right-only keys in right-side order. Every
operation rebuilds through semantic validation.

The fingerprint includes ordered question IDs, question types/instructions,
Choice option values/labels/order, Score levels/order/labels, Noul configuration,
and serialized/validation-relevant extras. It excludes credentials, client or
process state, retry configuration, cancellation tokens, concurrency, telemetry,
timestamps and loggers.

## Strict response contracts

Defaults preserve 0.2 behavior. Opt in per client or call:

```elixir
TypeSafeSDK.evaluate(client, state, prepared,
  response_contract: [
    on_unknown_answer: :error,
    allowed_models: ["jev-2026-09"]
  ]
)
```

`:error` rejects future/unknown answer IDs that cannot be associated with the
Prepared request. `allowed_models` is exact membership only; no prefixes or
fuzzy matching are used. Contract errors expose bounded structural metadata,
never raw request/response bodies or question text.

## Serialized request-byte budgets

```elixir
client = TypeSafeSDK.new_client(api_key: key, max_request_bytes: 262_144)

# A per-call value wins. Explicit nil disables the client budget for this call.
TypeSafeSDK.evaluate(client, state, prepared, max_request_bytes: 131_072)
```

The limit is measured from the same JSON request value that TypeSafe is about to
pass to the generated/Pristine execution path. Oversized requests fail locally
before transport egress. Error metadata contains only actual and maximum byte
counts plus safe structural context.

## Model helpers

```elixir
{:ok, catalog} = TypeSafeSDK.list_models(client)
{:ok, model} = TypeSafeSDK.Models.find(catalog, "jev")
model = TypeSafeSDK.Models.find!(catalog.models, "jev")
{:ok, latest} = TypeSafeSDK.Models.latest(catalog, :all)
```

Lookup is exact. `latest/2` uses the structured `release_date`; invalid dates or
ties that cannot be resolved objectively return an unordered-catalog error
instead of guessing from lexical or provider-return order.

## Stable metadata

```elixir
TypeSafeSDK.Response.metadata(response)
TypeSafeSDK.Error.metadata(error)
```

The accessors return bounded structural fields such as model/request IDs, usage,
timing/retry counts, cancellation state, contract/budget violation data and the
Prepared fingerprint when available. They never expose API keys, authorization
headers, question/state text, raw request bodies, raw response bodies or opaque
runtime internals.
