# TypeSafeSDK 0.4.0 implementation handoff

Release target: **0.4.0**
Date: **2026-09-17**

## Status

This checkout contains a **follow-on addition to the same unreleased 0.4.0**:
comprehensive live examples plus first-class alternate-endpoint selection. It was
prepared in an environment without Elixir/Erlang/Mix, so the follow-on has **not**
yet been formatted/compiled/tested on the BEAM or exercised against a live API.
Use `AGENT_HANDOFF_LIVE_EXAMPLES_0.4.0.md` for the exact finish/QC/commit-push
sequence.

The prior finalization commit `89086c33a6c94623289aafabd18a5cb8ede8c5e3` did
complete target-host QC on 2026-09-17 with Elixir 1.19.5 / OTP 28.3.1, including
the then-current offline/live gates. That evidence is historical baseline evidence,
not proof that this follow-on overlay passes. Hex publication and the `v0.4.0` tag
remain intentionally pending.

Pristine compatibility was verified against the published Hex `pristine 0.4.0`
source, including cancellation creation/validation/watch/stop semantics, runtime
capability discovery and the generated request execution path. The original
misnamed attachment is no longer a release blocker.

Maintenance tools are not yet available on Hex. Use the CI bootstrap in
`.github/actions/setup/action.yml`, pinned to Pristine commit
`04ba7b112413591f5cb9260f1d270bbbeb8a0630`, for `pristine_codegen` and
`pristine_provider_testkit` only. Runtime dependencies remain published Hex
packages; package metadata retains ordinary Hex requirements.

Finalization fixed cancellation watcher completion handling (which previously
hung cleanup), private-token cleanup on worker exit, typed unsupported-cancellation
errors, formatting/static-analysis failures, a hidden documentation link and
release-test assumptions. Reach now explicitly analyzes `lib` and `codegen` so
unpacked historical packages cannot shadow current modules. Added regression
coverage checks worker exceptions, pending status privacy and future-answer
telemetry/projection behavior.

## Implemented 0.4.0 features

### 1. Executable architecture boundaries

Added `.reach.exs`, `reach ~> 2.8` as dev/test tooling, and the gate:

```bash
mix reach.check --arch --smells
```

It is wired into `mix ci`, `.github/workflows/ci.yml` quality checks, and
`scripts/check_handoff.sh`.

The configured handwritten layers are:

- semantic: Question/Prepared/Answer/Response/request-contract modules;
- orchestration: Evaluation/Batch/Telemetry/OTP.Server;
- runtime: Client/SystemOne/Pristine integration/capability modules.

Forbidden directions are semantic -> orchestration, semantic -> runtime, and
runtime -> orchestration. Generated modules and data-only response structs are
intentionally not modeled by this small Reach graph.

### 2. Privacy-safe per-answer telemetry

`TypeSafeSDK.Telemetry.answers/3` is called only after successful semantic
response enrichment/validation. `evaluate/4` now emits one
`[:typesafe_sdk, :answer]` event for each known answer in Prepared order.

Measurements:

- `confidence`;
- `top_probability`;
- `distribution_margin`.

Metadata:

- `answer_type`;
- zero-based `question_index`;
- bounded model/request IDs;
- Prepared fingerprint;
- explicit caller telemetry metadata.

It deliberately omits question IDs/text, selected Choice labels, Noul direction,
Score values, state, bodies, headers, credentials, raw errors, and OTP tags.

### 3. `TypeSafeSDK.Response.values/1`

Added a convenience projection:

- Noul -> numeric probability;
- Choice -> selected caller key;
- Score -> expected numeric score.

Caller question keys are preserved. Unknown future answer types remain only in
`unknown_answers`. This is not a second response hierarchy.

### 4. Bounded OTP facade

Added `TypeSafeSDK.OTP.Server`.

Important design constraints:

- no SDK-global `Application` child or global TaskSupervisor;
- host supplies a running `Task.Supervisor`;
- host supplies the existing `TypeSafeSDK.Client`;
- `max_in_flight` defaults to 32 and is bounded to 1..1024;
- semantic requests use the normal `TypeSafeSDK.Evaluation.run/4` path;
- typed response/error structs are preserved;
- callbacks launch work with explicit `{:evaluate, ...}` rather than overloading
  ordinary GenServer `{:reply, ...}` semantics;
- opaque tags return to `handle_evaluation/3` but are not automatically logged;
- every request gets a private wrapper-owned `Pristine.Cancellation` token;
- caller-supplied cancellation is mirrored into that private token by a temporary
  Pristine watcher, so the caller token is never mutated by the server;
- the wrapper traps exits so orderly supervisor shutdown enters cleanup;
- the watcher is stopped and the private token is cancelled before local task
  shutdown;
- `format_status/1` exposes inner state plus counts, not pending tags/client/task
  internals.

Review `guides/otp-server.md` and `test/typesafe_sdk/otp_server_v040_test.exs`.

### 5. Recursive decision patterns

Added `guides/recursive-decisions.md` covering:

- hierarchical descent;
- bisection;
- verify/repair over shrinking candidate sets;
- coarse-to-fine cascades;
- bounded clarifying conversations;
- recursive OTP workflows.

`examples/live_recursive_decisions.exs` now executes all five documented patterns
with real responses and explicit termination bounds. Additional focused live scripts
cover 0.3 composition/contracts/runtime controls/cancellation and the 0.4 OTP facade;
`examples/README.md` contains the feature-to-example/test coverage matrix and finite
request-count bounds.

### 6. Jev credit

README Acknowledgements now credits:

https://github.com/dannote/jev

The credit is specific to OTP process composition, opaque in-flight correlation,
recursive workflows, per-answer telemetry, and architecture gates. It explicitly
states that TypeSafeSDK did not copy Jev's transport/global-supervisor design.

## Release/version/docs work

The source release version is bumped to 0.4.0 in:

- root `mix.exs`;
- `TypeSafeSDK.version/0`;
- README install/current-release text;
- committed JSON Schema release markers;
- release consistency tests;
- cheatsheet and current getting-started/example docs;
- CHANGELOG;
- 0.4 migration/implementation docs.

Historical 0.2/0.3 release notes and migration material remain historical and
must not be globally rewritten.

## Target-host verification sequence

Run from a clean checkout with the pinned maintenance-only bootstrap described
above. Do not substitute sibling runtime sources for release verification.

```bash
mix deps.get
mix typesafe.prereq
mix format
mix format --check-formatted
mix compile --warnings-as-errors
mix test --warnings-as-errors
mix reach.check --arch --smells
mix credo --strict
mix dialyzer
mix docs --warnings-as-errors
mix typesafe.schema.verify
mix typesafe.verify --project-root .
mix hex.build --unpack
mix ci
```

Then review the formatter diff. Formatting may touch files written in this
static environment; keep only legitimate formatting changes.

### Required focused tests

At minimum verify:

```bash
mix test test/typesafe_sdk/semantic_telemetry_test.exs
mix test test/typesafe_sdk/semantic_response_test.exs
mix test test/typesafe_sdk/otp_server_v040_test.exs
mix test test/typesafe_sdk/release_consistency_test.exs
```

### OTP facade focused coverage

`test/typesafe_sdk/otp_server_v040_test.exs` now covers the happy path,
`max_in_flight` rejection before transport, out-of-order caller correlation,
server/request option merge, duplicate-option rejection before transport,
caller-token cancellation propagation through the private request token, saturated
TaskSupervisor normalization, recursive `handle_evaluation/3`, caller-token
ownership during server shutdown, status projection, and missing-supervisor setup.

On the BEAM, pay particular attention to cancellation races and supervisor shutdown.
If an execution-path exception can escape `Evaluation.run/4` in the real Pristine
stack, add a focused test proving it is normalized to the OTP worker-exit path and
does not crash the wrapped server. Also confirm `:sys.get_status/1` / Observer output
never exposes pending tags, API keys, cancellation tokens, or task structs.

### Telemetry checks

Confirm event ordering is start -> answer events -> stop for a successful call.
Confirm unknown future answers do not emit a semantic answer event. Confirm no
question key/label is present in metadata/measurements.

### Reach check

If Reach reports a real pre-existing dependency violation, do not weaken the
boundary just to make the gate green. First determine whether the module was
misclassified in `.reach.exs` or the dependency actually crosses the intended
semantic/runtime boundary. Generated modules and plain data structs should stay
outside the modeled layers unless there is a clear reason to include them.

## Live gates

Only after offline gates are green and with an explicit real credential:

```bash
mix test --include live --warnings-as-errors
mix run examples/live_composition_contracts.exs
mix run examples/live_runtime_controls.exs
mix run examples/live_observability.exs
mix run examples/live_otp_server.exs
mix run examples/live_recursive_decisions.exs
# Full finite suite (including evaluation workflow); see examples/README.md for cost bound:
bash examples/run_all.sh
```

Live success does not prove calibration, transport queue bounds, or remote
cancellation semantics.

## Pristine source verification

Verified directly in `deps/pristine` from Hex 0.4.0, with the committed lockfile:

- `Pristine.Cancellation.new/0`, `cancel/1`, `validate/1`, `watch/2` and
  `stop_watcher/1`;
- `Pristine.RuntimeCapabilities.transport/1`;
- `Pristine.execute_request/3` and the existing generated/client path;
- the unchanged `{:pristine, "~> 0.4.0"}` runtime requirement.

The original attachment named `pristine_sdk.xml` was identical to the TypeSafeSDK
baseline, SHA-256
`c3279fb98ae60f9a0920ef48e5d8fd7332f3fd37bb379361b3817bae8b4bca0a`.
It was not used as dependency compatibility evidence.

## Packaging/release checks

Inspect the unpacked Hex package and confirm it contains the new runtime module,
guides, examples and 0.4 implementation record, while checkout-only `.reach.exs`
and dev/test tooling remain non-runtime concerns as intended.

Do not publish or tag until all applicable gates are green. After the follow-on
QC is green, update `VERIFICATION.md` with exact observed results, then commit and
push the ordinary development/release branch so the normal push-triggered GitHub
CI runs for that exact commit. Suggested follow-on commit message:

```text
feat: complete 0.4 live examples and endpoint selection
```

The follow-on authorization includes finishing QC, committing, and pushing the
branch. It does **not** include Hex publication or creation/push of `v0.4.0`; those
remain separate maintainer release steps after final-commit CI is green.
