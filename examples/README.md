# Live examples for TypeSafeSDK 0.4.0

Every standalone `live_*.exs` entrypoint uses the real TypeSafeSDK -> generated
operation -> Pristine HTTP path. There are no fixtures, recordings, local fake
servers, offline success modes, or network-failure fallbacks in these scripts.
Synthetic **inputs** are used to keep the examples safe and reproducible; all
advertised live **outputs** come from the selected API endpoint. Calls may incur
charges.

## Select the endpoint and model first

The examples are not tied to one vendor hostname. With no endpoint/model override,
the SDK defaults remain `https://api.typesafe.ai` and `jev-latest`. To use another
TypeSafe-compatible deployment, set all credentials and identifiers for that
provider deliberately:

```bash
export TYPESAFE_API_KEY='credential-issued-for-this-endpoint'
export TYPESAFE_BASE_URL='https://provider.example/deployments/my-typesafe-root'
export TYPESAFE_DEFAULT_MODEL='provider-model-id'

bash examples/run_all.sh
```

`TYPESAFE_BASE_URL` is the API **root before** the generated `/v1/models` and
`/v1/systemone` operation paths. A path prefix is allowed and is retained, so the
example above targets:

```text
https://provider.example/deployments/my-typesafe-root/v1/models
https://provider.example/deployments/my-typesafe-root/v1/systemone
```

The selected endpoint must implement the TypeSafe operation/request/response
contract and bearer authentication expected by this SDK. A generic
OpenAI-compatible endpoint is not automatically TypeSafe-compatible. API keys,
model IDs, supported operations, and deployment URLs belong to the selected
provider; never send a credential issued by one provider to a guessed third-party
URL. No provider-specific Cloudflare URL or model is assumed here.

Explicit executable options win over environment/host defaults. The evaluation
CLI accepts `--base-url` and `--model`; `mix typesafe.record` accepts the same
options. Standalone scripts use `TYPESAFE_BASE_URL` and
`TYPESAFE_DEFAULT_MODEL`, then fall back to host application config/defaults.
Blank or invalid explicit endpoint/model settings fail instead of silently
contacting another provider.

For ordinary application code, construct the client explicitly when that makes
provider selection clearest:

```elixir
client =
  TypeSafeSDK.new_client(
    api_key: provider_key,
    base_url: "https://provider.example/deployments/my-typesafe-root",
    model: "provider-model-id"
  )
```

Or map the same environment names in the **host application's**
`config/runtime.exs` (a dependency's runtime config does not configure its host):

```elixir
import Config

config :typesafe_sdk,
  api_key: System.fetch_env!("TYPESAFE_API_KEY"),
  base_url: System.get_env("TYPESAFE_BASE_URL", "https://api.typesafe.ai"),
  default_model: System.get_env("TYPESAFE_DEFAULT_MODEL", "jev-latest")
```

Runtime modules under `lib/**` do not read OS environment variables. Executable
examples/Mix tasks may do so in order to make live endpoint selection explicit.

## Run everything

Run from the repository root after the source-checkout dependency/bootstrap steps
in the main README:

```bash
read -rsp "TypeSafe API key: " TYPESAFE_API_KEY
echo
export TYPESAFE_API_KEY
# Optional alternate provider settings:
# export TYPESAFE_BASE_URL='https://provider.example/deployment-root'
# export TYPESAFE_DEFAULT_MODEL='provider-model-id'

bash examples/run_all.sh
```

The runner stops on failure. Retries are disabled by default. Its bounded default
path has a **63-request hard upper bound** across the standalone scripts plus the
12 development and eight held-out evaluation rows. Conditional recursive and
cancellation branches can make fewer requests. Setting
`TYPESAFE_EXAMPLE_RETRY=1` explicitly enables one bounded retry-configuration
operation (`max_retries: 1`), adding at most two HTTP attempts (65 total attempts for the full runner). Do not blindly
rerun an ambiguous failure: remote processing may already have happened.

## Runnable catalog

| Command | Live coverage | Maximum live requests |
| --- | --- | ---: |
| `mix run examples/live_evaluation.exs` | Model list; retained wire-oriented `Noul`/`Choice`/`Score`; `system_one!`; typed answers/usage | 2 |
| `mix run examples/live_semantic.exs` | Strict constructors; descriptions/labels; caller-key restoration; Prepared reuse; `evaluate`; fetch/filter/raw access; uncertainty helpers | 2 |
| `mix run examples/live_composition_contracts.exs` | Prepared `keys/count/put/delete/take/merge`; ordering/right bias/immutability; fingerprints; exact model helpers/objective latest; client/per-call response contracts; request-byte budgets; `Response.values/metadata`; privacy-conscious raw escape hatches | 5 |
| `mix run examples/live_runtime_controls.exs` | Client/per-call timeout precedence; explicit retry disable; opt-in bounded retry config; protected semantic extras/headers; retained legacy extra-body merge; capability discovery; unary and batch cancellation races/cleanup | 6 default (+2 retry opt-in) |
| `mix run examples/live_batching.exs` | Ordered/unordered bounded batches; `batch_index`; streaming; collect/raise; task/attempt budgets; early halt | 8 |
| `mix run examples/live_observability.exs` | Span telemetry plus Noul/Choice/Score answer events in Prepared order; nested caller metadata; privacy assertions; capability report; schema check | 1 |
| `mix run examples/live_decision_patterns.exs` | Weighted Score composition; explicit confidence policy; supervised speculative real model lookup and cleanup | 3 |
| `mix run examples/live_otp_server.exs` | Real `TypeSafeSDK.OTP.Server`; caller-owned `Task.Supervisor`; `max_in_flight`; simultaneous callers/correlation; server/per-request options; private-vs-caller cancellation ownership; recursive `handle_evaluation/3`; shutdown cleanup | 4 |
| `mix run examples/live_recursive_decisions.exs` | Hierarchical descent, bisection, verify/repair, coarse-to-fine cascade, and bounded clarification; all branches driven by live answers | 12 |
| `mix run examples/evaluation/run.exs -- ...` | Development/held-out decision evaluation; model vs policy metrics; sweep; frozen observed model/policy | one request per dataset row |

`support/live.exs` and `evaluation/evaluation.exs` are supporting modules, not
standalone entrypoints. See [the evaluation README](evaluation/README.md) for the
full CLI.

## 0.2 -> 0.4 feature-to-example matrix

“Live” means a runnable path exercises the real external API. “Deterministic”
identifies guarantees that are more honestly asserted in tests/tooling because a
successful network response cannot force every error/race/future condition.

| Public feature / guarantee | Live demonstration | Deterministic / deeper coverage |
| --- | --- | --- |
| Legacy model listing + `system_one` wire surface | `live_evaluation.exs` | `guides/system-one-and-questions.md` |
| Strict Noul/Choice/Score constructors and local validation | `live_semantic.exs` | `test/typesafe_sdk/semantic_questions_test.exs`, `guides/semantic-questions.md` |
| Prepared validation/reuse and caller atom/string restoration | `live_semantic.exs` | `test/typesafe_sdk/semantic_response_test.exs` |
| Prepared composition, source order, right-biased merge, immutable reuse | `live_composition_contracts.exs` | `test/typesafe_sdk/prepared_v030_test.exs`, `guides/migration-0.3.md` |
| Stable Prepared fingerprints + response/error propagation | `live_composition_contracts.exs` | `test/typesafe_sdk/metadata_v030_test.exs` |
| Enriched Noul/Choice/Score answers; ranking/margin/expected/modal/normalized helpers; explicit gates | `live_semantic.exs`, `live_decision_patterns.exs` | `guides/answers-and-confidence.md`, `guides/confidence-routing.md` |
| `Response.fetch/filter`, `Response.values`, stable `Response.metadata` | `live_semantic.exs`, `live_composition_contracts.exs`, `live_otp_server.exs` | response/metadata ExUnit suites |
| Raw response/answer escape hatches without logging credentials | `live_semantic.exs`, privacy-conscious status/key view in `live_composition_contracts.exs` | `guides/answers-and-confidence.md` |
| Bounded ordered/unordered batch evaluation and early-halt cleanup | `live_batching.exs` | `test/typesafe_sdk/batch_test.exs`, `guides/batching.md` |
| Shared batch cancellation / no new scheduling after observed cancellation | `live_runtime_controls.exs` | `test/typesafe_sdk/runtime_controls_v030_test.exs` |
| Unary cancellation capability discovery and race-safe outcomes | `live_runtime_controls.exs` | runtime-control tests; Pristine capability contract |
| Client/per-call timeouts | `live_runtime_controls.exs` | runtime/client tests |
| Retry inheritance/merge and `retry: false` | disabled throughout; optional bounded live config in `live_runtime_controls.exs` | retry-policy/runtime tests; live success does **not** prove a retry occurred |
| Protected headers and strict semantic protected `extra_body`; legacy last-write-wins extras | `live_runtime_controls.exs` | `test/typesafe_sdk/runtime_test.exs` asserts exact serialized request/headers |
| Client/per-call strict response contracts + exact allowed model | `live_composition_contracts.exs` using an observed model ID | `test/typesafe_sdk/response_contract_v030_test.exs`; future unknown-answer branch is test-only |
| Client/per-call serialized request-byte budgets and explicit `nil` disable | `live_composition_contracts.exs` (success + intentional local preflight rejection) | runtime-control tests assert no egress on rejection |
| Exact `Models.find/find!` and objective `Models.latest` | `live_composition_contracts.exs` using returned model IDs | `test/typesafe_sdk/models_v030_test.exs`; ambiguous/invalid catalog failures are deterministic tests |
| Stable `Error.metadata` | cancellation/local validation paths in live scripts where naturally reachable | `test/typesafe_sdk/metadata_v030_test.exs` |
| Semantic span telemetry | `live_observability.exs` | `test/typesafe_sdk/semantic_telemetry_test.exs` |
| Per-answer Noul/Choice/Score telemetry and ordering/privacy | `live_observability.exs` | semantic telemetry tests cover future/exception branches |
| Weighted scoring and speculative fan-out | `live_decision_patterns.exs` | composite/speculative guides |
| `TypeSafeSDK.OTP.Server`, async replies, opaque correlation, option precedence, ownership/cleanup | `live_otp_server.exs` | `test/typesafe_sdk/otp_server_v040_test.exs` covers saturation, crashes, unsupported cancellation and exact lifecycle races |
| Hierarchical, bisection, verify/repair, coarse-to-fine, clarification workflows | `live_recursive_decisions.exs`; OTP recursion also in `live_otp_server.exs` | `guides/recursive-decisions.md`; explicit finite bounds stay application-owned |
| Labeled development/held-out evaluation | `examples/evaluation/run.exs` | `test/typesafe_sdk/evaluation_example_test.exs`, `guides/evaluating-decisions.md` |
| Runtime capability reporting/fail-closed requirements | `live_runtime_controls.exs`, `live_observability.exs` | `test/typesafe_sdk/runtime_capabilities_test.exs` |
| Alternate endpoint/model precedence and path-prefix preservation | every live entrypoint; CLI `--base-url/--model` | `live_example_configuration_test.exs`, `client_configuration_test.exs`, `runtime_test.exs` |
| `TypeSafeSDK.Test` fixture API | **Not live by design** | `guides/testing.md` and ExUnit. It must never masquerade as a production example. |
| JSON Schema/codegen freshness | schema check accompanies `live_observability.exs`, but is not a network proof | `guides/json-schemas.md`, `mix typesafe.schema.verify`, `mix typesafe.verify` |
| Reach architecture boundaries | **Not a live behavior** | `mix reach.check --arch --smells`, `.reach.exs` |
| Future unknown wire types, deterministic overload/failures/race ordering | **Cannot be honestly forced by a healthy live service** | targeted ExUnit fixtures/tests retain these guarantees |

## Cancellation, failures, and privacy

A real request can complete before cancellation wins. Both completion and typed
`:cancelled` outcomes are legitimate in `live_runtime_controls.exs`; the example
uses no arbitrary delay or fake slow transport. Cancellation stops/cleans local
work according to advertised Pristine capabilities but does not prove remote
non-execution or rollback.

`TypeSafeSDK.OTP.Server` creates a **private** cancellation token for each worker.
A caller-provided token remains caller-owned; a watcher only mirrors caller
cancellation inward. The live OTP example checks that normal private cleanup does
not mutate the caller token. Deterministic shutdown/worker-exit/saturation cases
remain in ExUnit rather than manipulating a paid service into failure.

The shared failure path prints only bounded structural `Error.metadata`. Do not
replace synthetic example state with private data unless you intend that data to
be sent to the selected provider. API keys are never printed.

## Evaluation and live capture entrypoints

The evaluation CLI exposes its endpoint/model workflow directly:

```bash
mix run examples/evaluation/run.exs -- --help
mix run examples/evaluation/run.exs -- \
  --base-url "$TYPESAFE_BASE_URL" \
  --model "$TYPESAFE_DEFAULT_MODEL" \
  --split development --sweep --output tmp/examples/development.json
```

The live capture task follows the same precedence:

```bash
mix typesafe.record \
  --base-url "$TYPESAFE_BASE_URL" \
  --model "$TYPESAFE_DEFAULT_MODEL" \
  --output tmp/live --baseline test/fixtures/live
```

Only use those explicit options when the matching endpoint, credential, and model
are actually authorized. The scheduled `.github/workflows/live.yml` capture also
accepts optional repository variables `TYPESAFE_BASE_URL` and
`TYPESAFE_DEFAULT_MODEL`; the existing `TYPESAFE_API_KEY` secret must correspond to
that selected endpoint. Reports/captures go under ignored `tmp/` paths; no example
publishes, tags, commits, or updates approved fixtures automatically.
