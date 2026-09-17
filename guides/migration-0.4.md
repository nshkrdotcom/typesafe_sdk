# Migrating from 0.3.x to 0.4.0

TypeSafeSDK 0.4.0 is additive. It keeps the generated OpenAPI operations,
semantic constructors, Prepared contracts, Pristine runtime ownership,
cancellation behavior, batching, schemas, and 0.3 response contracts intact.

```elixir
{:typesafe_sdk, "~> 0.4.0"}
```

## Response value projection

`TypeSafeSDK.Response.values/1` returns only the primary semantic values while
preserving the caller's question keys:

```elixir
%{urgent: 0.91, team: :billing, severity: 1.7} =
  TypeSafeSDK.Response.values(response)
```

This does not replace answer structs. Use `Response.fetch!/2` and the `Answer.*`
helpers when confidence, distributions, labels, or rubrics matter. Unknown future
answer types remain in `response.unknown_answers` and are not projected.

## Per-answer telemetry

Successful semantic evaluations now emit one `[:typesafe_sdk, :answer]` event per
validated known answer, in Prepared question order. Measurements contain only
confidence/distribution shape (`confidence`, `top_probability`,
`distribution_margin`). Metadata contains `answer_type`, zero-based
`question_index`, bounded model/request identifiers, Prepared fingerprint, and
the explicit caller metadata already supplied through `telemetry_metadata:`.

The event does not include state, question text, question IDs, selected labels,
Score values, Noul direction, raw bodies, headers, credentials, exception reasons,
or pending OTP tags. Consumers that require business labels should join against
their own explicitly controlled evaluation records rather than turning global
telemetry into a content log.

## OTP server integration

`TypeSafeSDK.OTP.Server` is optional and starts no global SDK process. Applications
provide a running `Task.Supervisor`, a `TypeSafeSDK.Client`, and an explicit
`max_in_flight` bound. See [Bounded OTP Server Integration](otp-server.md).

## Recursive decision patterns

The new [Recursive Decision Patterns](recursive-decisions.md) guide covers
hierarchical descent, bisection, verify/repair, coarse-to-fine cascades, and
clarifying loops using existing SDK primitives rather than a new workflow engine.

## Architecture gate

Source CI now runs `mix reach.check --arch --smells`. `.reach.exs` enforces that
handwritten semantic modules cannot reach orchestration/runtime modules and that
runtime integration cannot reach upward into orchestration. Generated modules and
data-only response structs are intentionally outside this small boundary model.
