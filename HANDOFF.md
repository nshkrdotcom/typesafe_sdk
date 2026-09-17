# TypeSafeSDK 0.3.0 implementation handoff

Release target: **0.3.0**

The dependency publication train is complete; TypeSafe remains unpublished and
untagged by maintainer request. See the latest closure below.

Target-host QC was executed on 2026-09-17 after this source-overlay handoff.
See the closure record appended below and `VERIFICATION.md`; the original
container limitations below are historical.

Release date: **2026-09-17**

Baseline: supplied TypeSafeSDK 0.2.0 Repomix source

Runtime reference: supplied Pristine 0.4.0 source

## Implementation summary

This change set implements the full requested TypeSafeSDK 0.3.0 semantic/runtime
control layer while preserving Pristine as the only HTTP/resilience runtime.
The implementation adds direct Pristine cancellation forwarding, fail-closed
runtime capability delegation, cancellation-aware bounded batching, structural
retry-policy inheritance, Prepared composition/fingerprints, opt-in strict
response contracts, serialized request-byte budgets, pure model-catalog helpers,
and privacy-safe response/error metadata.

0.2 behavior remains the default where required: strict response contracts and
request budgets are opt-in, the raw/parity path remains available, existing
semantic constructors/enriched answers/test seams remain in place, and TypeSafe
does not implement its own HTTP client, retry loop, circuit breaker, global
queue, or physical cancellation transport.

## Architecture decisions

- **Cancellation ownership:** callers pass the exact `Pristine.Cancellation`
  token. TypeSafe validates/forwards it, preserves `%Pristine.Error{type:
  :cancelled}` as the cause, and stops future batch scheduling. Physical unary
  cancellation and retry-wait cancellation remain Pristine 0.4 responsibilities.
- **Capability discovery:** `TypeSafeSDK.RuntimeCapabilities` delegates to
  `Pristine.RuntimeCapabilities.transport/1`. Missing/malformed support remains
  `:unverified`; no adapter-name or callback-presence inference is used.
- **Retry ownership:** provider/Pristine defaults -> client defaults -> per-call
  override. Omitted per-call fields inherit. `false` disables. TypeSafe only
  resolves policy and projects it into Pristine; it never executes a retry.
- **Prepared compatibility:** the existing `%Prepared{keys: wire_to_caller}`
  field is retained for 0.2 struct compatibility. The new public
  `Prepared.keys/1` returns ordered caller keys. Composition always rebuilds via
  `Prepared.new/1`, re-running semantic/request-relative validation.
- **Fingerprint:** `typesafe-prepared-v1:<sha256>` hashes only deterministic
  semantic request meaning/order. Runtime state, credentials, retry settings,
  cancellation, concurrency, telemetry, timestamps and loggers are excluded.
- **Request bytes:** the same request map handed to the generated operation is
  JSON-sized before egress; an oversized request fails locally without exposing
  the body in error metadata.
- **Response contracts:** default behavior remains 0.2-compatible. Strict
  unknown-answer and exact allowed-model checks are opt-in and reuse the existing
  `%TypeSafeSDK.Error{}` hierarchy.
- **Model helpers:** lookup is exact; latest selection uses objective
  `release_date` ordering and fails closed on invalid/tied ordering.
- **Metadata:** public metadata helpers expose bounded structural fields only;
  no credentials, auth headers, prompt/state/question text, raw bodies, or opaque
  transport internals are returned.

## Pristine 0.4.0 integration

`mix.exs` now requires `pristine ~> 0.4.0`. TypeSafe consumes these supplied
Pristine contracts directly:

- `Pristine.Cancellation`;
- `%Pristine.Error{type: :cancelled}`;
- `Pristine.RuntimeCapabilities.transport/1`;
- optional transport cancellation capabilities/`send_cancelable/3` through
  Pristine's own pipeline; and
- Pristine-owned cancellation-aware Foundation retry waits/classification.

TypeSafe does **not** depend directly on `execution_plane_http` and does not add
Finch/Mint/Req/HTTPoison/Hackney as a second runtime stack.

## Exact modified files (40)

- `AGENTS.md`
- `CHANGELOG.md`
- `HANDOFF.md`
- `PORT_PARITY.md`
- `PUBLISHING.md`
- `README.md`
- `VERIFICATION.md`
- `cheatsheets/typesafe_sdk.cheatmd`
- `examples/README.md`
- `guides/batching.md`
- `guides/client-configuration.md`
- `guides/errors-and-retries.md`
- `guides/generation-and-verification.md`
- `guides/getting-started.md`
- `guides/index.md`
- `guides/models.md`
- `guides/runtime-capabilities.md`
- `lib/mix/tasks/typesafe.capabilities.ex`
- `lib/mix/tasks/typesafe.prereq.ex`
- `lib/typesafe_sdk.ex`
- `lib/typesafe_sdk/batch.ex`
- `lib/typesafe_sdk/client.ex`
- `lib/typesafe_sdk/error.ex`
- `lib/typesafe_sdk/evaluation.ex`
- `lib/typesafe_sdk/models.ex`
- `lib/typesafe_sdk/prepared.ex`
- `lib/typesafe_sdk/response.ex`
- `lib/typesafe_sdk/retry_policy.ex`
- `lib/typesafe_sdk/runtime_capabilities.ex`
- `lib/typesafe_sdk/semantic_response.ex`
- `lib/typesafe_sdk/system_one.ex`
- `lib/typesafe_sdk/system_one_response.ex`
- `lib/typesafe_sdk/test/transport.ex`
- `mix.exs`
- `priv/json_schema/models-response.json`
- `priv/json_schema/system-one-request.json`
- `priv/json_schema/system-one-response.json`
- `test/typesafe_sdk/release_consistency_test.exs`
- `test/typesafe_sdk/runtime_capabilities_test.exs`
- `test/typesafe_sdk/schema_test.exs`

## Exact new files (10)

- `docs/implementation/0.3.0/README.md`
- `guides/migration-0.3.md`
- `guides/runtime-controls.md`
- `lib/typesafe_sdk/request_budget.ex`
- `lib/typesafe_sdk/response_contract.ex`
- `test/typesafe_sdk/metadata_v030_test.exs`
- `test/typesafe_sdk/models_v030_test.exs`
- `test/typesafe_sdk/prepared_v030_test.exs`
- `test/typesafe_sdk/response_contract_v030_test.exs`
- `test/typesafe_sdk/runtime_controls_v030_test.exs`

No files are intentionally deleted by this overlay.

## Source/static checks actually run

The delivery container has no `elixir`, `erl`, or `mix`. The following checks
were actually executed:

```text
git diff --check
  -> exit 0

bash -n scripts/check_handoff.sh
bash -n examples/run_all.sh
  -> both exit 0

Python JSON/JSONL parse of repository data
  -> no parse failures

Release/version consistency screen
  -> TypeSafe 0.3.0, Pristine ~> 0.4.0, three schema markers 0.3.0,
     changelog date 2026-09-17

Required-API/boundary screen
  -> all requested 0.3 marker groups present
  -> no new TypeSafe HTTP dependency/direct execution_plane_http dependency

Relative Markdown-link resolution
  -> no missing relative targets

Elixir source lexical screen
  -> delimiter screen over repository .ex/.exs files reported no findings
  -> single-backslash default-argument typo screen reported no findings

Changed-file placeholder screen
  -> no TODO/TBD/FIXME findings
```

These checks do not prove that Elixir code compiles. `VERIFICATION.md` records
the same boundary explicitly.

## TDD status

Focused 0.3 ExUnit tests were added for the requested behaviors. A static RED
screen against the reconstructed 0.2 baseline established that the new public
API markers were absent before implementation. Executable ExUnit RED/GREEN runs
were impossible because the container has no BEAM toolchain; do not represent
these tests as passed until they run on the target host.

## Required target-host commands

Run from the repository root in the real Elixir/OTP environment:

```bash
mix deps.get
mix typesafe.prereq
mix format --check-formatted
mix compile --warnings-as-errors
mix test
mix credo --strict
mix dialyzer
mix docs --warnings-as-errors
mix typesafe.schema.verify
mix typesafe.verify --project-root .
mix hex.build --unpack
mix ci
```

Then run the repository's configured compatibility matrix. If release policy
requires credentialed acceptance, run:

```bash
mix test --include live --warnings-as-errors
bash examples/run_all.sh
mix typesafe.record --output tmp/live --baseline test/fixtures/live
```

The live operations can incur charges. Cancellation proves local transport
termination only when the configured Pristine transport advertises verified
support; it does not prove the remote service never received/began the request
and does not roll back remote side effects.

## Remaining compile/runtime risks

1. **Compiler/formatter confirmation:** all new Elixir source still needs real
   `mix format --check-formatted` and warnings-as-errors compilation.
2. **Pristine contract compatibility:** verify TypeSafe's option projection
   against the installed/published Pristine 0.4.0 package, not only the supplied
   reference source.
3. **Prepared golden vector:** run the fingerprint golden-vector tests under the
   pinned Jason/Elixir versions to confirm byte-for-byte canonical encoding.
4. **Serialized-size identity:** run no-egress tests to prove the measured body
   is the exact JSON representation ultimately serialized by the generated /
   Pristine path, including `Jason.Fragment` and Unicode boundaries.
5. **Cancellation races/cleanup:** run synchronized token-forwarding and batch
   cancellation tests to confirm worker/watcher/lifecycle cleanup under OTP.
6. **Static analysis/docs:** Credo, Dialyzer and ExDoc may expose style/type/link
   issues invisible to source screening.
7. **Generated freshness/package:** codegen/schema verification and unpacked Hex
   build must be run without regenerating first.

## First fixes if target-host verification exposes an issue

- For formatter-only failures, run `mix format`, inspect the diff, and keep only
  formatting changes.
- For Pristine option/capability mismatches, adapt the narrow TypeSafe projection
  to the actual 0.4 public contract; do not add a local retry/cancellation engine.
- For fingerprint failures, inspect canonical semantic encoding and update code
  rather than weakening/removing the golden vector unless the versioned
  fingerprint contract itself is intentionally changed.
- For request-budget failures, keep one semantic request value for sizing and
  sending; do not introduce a second serializer representation.
- For batch cancellation failures, preserve existing `Batch.Lifecycle` ownership
  and fix scheduling/monitor cleanup rather than adding a global queue.
- For codegen/schema drift, identify whether upstream source actually changed;
  do not regenerate solely to make verification green.

## Release closure

Do not publish 0.3.0 until the BEAM gates above are green and their exact results
are appended to this handoff/`VERIFICATION.md`. Follow `PUBLISHING.md` after QC.

Suggested conventional commit subject:

```text
feat: release TypeSafe SDK 0.3.0 runtime controls and semantic contracts
```


## Target-host closure — 2026-09-17

The implementation was compiled and QC'd on Elixir 1.19.5 / OTP 28.3.1.
Executable checks required a qualified test-transport `send/2`, Pristine opaque
token validation, three fixture option corrections, formatting/Credo/ExDoc fixes,
and an explicit test environment in `mix ci`. No generated files were changed.

All local BEAM gates listed above passed, including the unchanged fingerprint
golden vector, schema/codegen freshness, unpacked package inspection and final
`mix ci`. Offline: 1 doctest + 121 tests, zero failures (2 excluded). With live
acceptance: 1 doctest + 123 tests, zero failures. All examples and first-capture
recording passed; captures were not promoted to approved fixtures.

The configured three-version test/freshness matrix passed with explicit sibling
source commits. A clean consumer of the unpacked release artifacts passed live
model listing, semantic evaluation, fingerprint metadata and cancellation.
Pristine root QC and HTTP package QC were rechecked; neither needed source edits.
See `VERIFICATION.md` for exact commands, counts, commits and evidence boundaries.

The release train is HTTP 0.2.0 (`execution_plane_http-v0.2.0`), Pristine 0.4.0
(`pristine-v0.4.0`), then TypeSafe 0.3.0 (`v0.3.0`). Execution-plane core remains
published 0.3.0. Fully Hex-resolved CI, real lock entries and the publish dry run
follow dependency publication; the source checks do not substitute for those
publish-train steps. No publication or tags were performed.


## Published-dependency closure — 2026-09-17

The dependency train is complete:

- `execution_plane_http 0.2.0` and docs published; tag
  `execution_plane_http-v0.2.0` pushed at `63b69ff3984f6f8440866e96a16ceee3ad73bf41`.
- `pristine 0.4.0` and docs published; tag `pristine-v0.4.0` pushed at
  `04ba7b1` after locking published HTTP 0.2.0 and passing 347 runtime tests,
  formatting, compilation, Credo, Dialyzer, docs and the full publish dry run.

TypeSafe now locks both actual Hex releases. With the maintenance-tools-only
bootstrap (no runtime source substitution), the complete `scripts/check_handoff.sh`,
final `mix ci` and `mix hex.publish --dry-run --yes` passed. Live tests passed:
1 doctest + 123 tests, zero failures. A fresh production consumer of the unpacked
TypeSafe artifact resolved every runtime dependency from Hex and passed compile,
live model listing/evaluation, fingerprint metadata and cancellation checks on
Elixir 1.19.5 / OTP 28.3.1. No source or generated changes were needed.

Normal GitHub CI must be green for the final pushed commit before publication;
use the push-triggered `ci.yml` run, with no source-ref inputs. The earlier
source-mode matrix below is historical preparation evidence.

**TypeSafeSDK 0.3.0 is intentionally not published or tagged.** The maintainer
requested a pause at the publish-ready handoff. Its future tag is `v0.3.0`.
See `PUBLISHING.md` for the remaining TypeSafe-only actions.
