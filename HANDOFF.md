# TypeSafeSDK 0.4.0 implementation handoff

Release target: **0.4.0**
Date: **2026-09-17**

## Status

The 0.4.0 source changes requested for the Jev-inspired work are implemented in
this overlay, but this delivery environment has no Elixir, Erlang, or Mix. The
next agent must run the BEAM/Hex gates below and fix any compile/format/static
analysis issues before treating the release as complete.

There is also one source-input problem that must be resolved explicitly: the file
supplied as the final `pristine_sdk.xml` is byte-for-byte identical to the
TypeSafeSDK 0.3.0 Repomix baseline. Both files have SHA-256:

`c3279fb98ae60f9a0920ef48e5d8fd7332f3fd37bb379361b3817bae8b4bca0a`

It therefore did **not** provide a distinct final Pristine repository to inspect.
Do not infer any new Pristine 0.3/0.4 compatibility claim from that attachment.
The implementation intentionally uses only Pristine APIs already present in the
0.3.0 TypeSafeSDK baseline: `Pristine.Cancellation`, the existing generated/client
execution path, and existing capability delegation. Verify those contracts
against the intended final Pristine source before publication.

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

Added `examples/live_recursive_decisions.exs`, a two-level hierarchical descent
using `Response.values/1`, and included it in `examples/run_all.sh`.

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

Run from a clean checkout after applying the overlay. Use the repository's normal
workspace bootstrap only when intentionally testing sibling source versions.

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
mix test --include live
mix run examples/live_observability.exs
mix run examples/live_recursive_decisions.exs
```

Live success does not prove calibration, transport queue bounds, or remote
cancellation semantics.

## Pristine source verification

Obtain the intended final Pristine Repomix/source and verify at least:

- `Pristine.Cancellation.new/0`, `cancel/1`, validation/watch semantics used by
  the existing TypeSafe runtime and new OTP wrapper;
- `Pristine.RuntimeCapabilities.transport/1` contract consumed by 0.3 code;
- generated/client execution signatures used by the existing baseline;
- the correct Hex package name/version requirement for TypeSafeSDK 0.4.0.

If the intended final dependency really is a different Pristine version than the
baseline's `{:pristine, "~> 0.4.0"}`, change the dependency only after verifying
source/API compatibility and rerun every gate. Do not guess from the filename.

## Packaging/release checks

Inspect the unpacked Hex package and confirm it contains the new runtime module,
guides, examples and 0.4 implementation record, while checkout-only `.reach.exs`
and dev/test tooling remain non-runtime concerns as intended.

Do not publish or tag until all applicable gates are green. Suggested commit
message after target-host verification:

```text
feat: add TypeSafe SDK 0.4.0 OTP composition and answer telemetry
```
