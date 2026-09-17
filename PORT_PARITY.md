# Python 0.6.0 -> Elixir 0.2.0 parity map

This file is a handoff index, not an additional runtime specification. The
supplied Python `typesafe-sdk` 0.6.0 repository remains the semantic oracle for
this initial port.

| Python surface | Elixir surface | Ownership |
| --- | --- | --- |
| `TypeSafeClient(...)` / `AsyncTypeSafeClient(...)` | `TypeSafeSDK.Client.new/1` | handwritten provider facade |
| `.system_one(...)` | `TypeSafeSDK.system_one/4`, `TypeSafeSDK.SystemOne.run/4` | handwritten ergonomic facade over generated operation |
| `.models.list(...)` | `TypeSafeSDK.list_models/2`, `TypeSafeSDK.Models.list/2` | handwritten ergonomic facade over generated operation |
| `Noul` | `TypeSafeSDK.Noul` | handwritten public type |
| `NoulCriteria` | `TypeSafeSDK.NoulCriteria.t()` | handwritten public type contract |
| `Choice` | `TypeSafeSDK.Choice` | handwritten public type |
| `Score` | `TypeSafeSDK.Score` | handwritten public type |
| `NoulAnswer` | `TypeSafeSDK.NoulAnswer` | handwritten public type |
| `ChoiceAnswer` | `TypeSafeSDK.ChoiceAnswer` | handwritten public type |
| `ScoreAnswer` | `TypeSafeSDK.ScoreAnswer` | handwritten public type |
| `Usage` | `TypeSafeSDK.Usage` | handwritten public token-count type; live wire schema also omits `billing_units` |
| `ModelMetadata` | `TypeSafeSDK.ModelMetadata` | handwritten public type |
| `SystemOneResponse` | `TypeSafeSDK.SystemOneResponse` | handwritten decoder + response metadata |
| `ListModelsResponse` | `TypeSafeSDK.ListModelsResponse` | handwritten decoder + response metadata |
| `RetryPolicy` | `TypeSafeSDK.RetryPolicy` | handwritten provider policy |
| TypeSafe exception hierarchy | `%TypeSafeSDK.Error{type: ...}` | idiomatic single Elixir exception/result type |
| generated Python wire models | `TypeSafeSDK.Generated.*` | PristineCodegen-owned, generated and verified |
| Python OpenAPI generator URL | `priv/upstream/openapi.json` + `TypeSafeSDK.Codegen.Source.OpenAPI` | committed deterministic source + bounded refresh |

## Intentional language/runtime adaptations

Elixir has one immutable client value rather than duplicated synchronous and
asynchronous client classes. Callers get concurrency from processes/Tasks.
Network APIs return `{:ok, value}` / `{:error, %TypeSafeSDK.Error{}}` rather
than raising for ordinary API failures.

Question maps remain forward-compatible. Unknown future answer tags are logged
and skipped while known malformed answer types fail with a precise field path.
Successful responses retain the TypeSafe request ID and raw `Pristine.Response`
metadata separately from the decoded public payload.

## Runtime prerequisite

Retry parity uses the locally completed contract in `PREREQUISITE_PRISTINE_0.3.0.md`.
Do not replace that prerequisite with 100 exact 5xx overrides. The completed
Pristine 0.3.0 provider profile supports an inclusive `500..599` range with
exact-status precedence, verified through the real classifier and SDK pipeline.

## 0.2.0 semantic additions above parity

The table above describes the preserved wire-oriented system_one/list_models
surface. Strict Question.* constructors, prepare/evaluate, caller identity,
relational validation, enriched answers, batch execution, application fixtures,
semantic telemetry, schema export and decision evaluation are provider-owned
Elixir additions. The underlying generated operations and Pristine execution
path are unchanged. In particular, protected `extra_body` behavior applies to
strict evaluate only; legacy system_one retains last-write-wins overrides.

Known probability ranges, nonnegative usage and normalized-key collision checks
are stronger than the old shallow decoder. Unknown future answer types still
skip typed decoding and are now retained explicitly in raw/unknown_answers.
The strict semantic level/option limits are not retroactively attributed to
Python 0.6.0 or the committed OpenAPI wire schema. See guides/migration-0.2.md.
