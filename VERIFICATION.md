# TypeSafeSDK 0.3.0 verification record

Release date: **2026-09-17**. Target-host QC supersedes the original overlay's
static-only verification. Runtime source: Pristine **0.4.0**; HTTP source:
Execution Plane HTTP **0.2.0**; core dependency: published Hex **0.3.0**.

## Target-host results

Executed with Elixir **1.19.5-otp-28 / OTP 28.3.1**, using the existing
machine-local MWO bootstrap for the two unpublished runtime dependencies and
maintenance packages. Committed package requirements remain ordinary Hex tuples.

All of these gates passed:

- `mix deps.get` and `mix typesafe.prereq`.
- `mix format --check-formatted` and `mix compile --warnings-as-errors`.
- `mix test --warnings-as-errors`: **1 doctest, 121 tests, zero failures,
  2 live tests excluded**.
- `mix credo --strict`: no findings.
- `mix dialyzer`: **zero errors, zero skips**.
- `mix docs --warnings-as-errors`.
- `mix typesafe.schema.verify` and `mix typesafe.verify --project-root .`.
  No upstream refresh or regeneration was performed.
- `mix hex.build --unpack`: package contents and ordinary Hex requirements
  inspected. Runtime source, schemas, upstream source, guides, examples,
  cheatsheet, assets and implementation records are present. Checkout tooling,
  tests, dependencies, build output, credentials and local captures are absent.
- `mix ci`: the complete aggregate gate passed. Its test command now explicitly
  uses `MIX_ENV=test`, while docs and development tooling stay in `dev`.

The executed suite includes the unchanged Prepared fingerprint golden vector,
request-byte/no-egress boundaries, retry inheritance, cancellation forwarding and
batch cancellation cleanup, response contracts, model helpers and metadata.

## Live and packaged-consumer acceptance

- `mix test --include live --warnings-as-errors`: **1 doctest, 123 tests,
  zero failures**, including both API operations.
- `bash examples/run_all.sh`: all examples and development/held-out evaluation
  workflows passed.
- `mix typesafe.record --output tmp/live --baseline test/fixtures/live`: passed.
  There are no approved live baselines; the command produced first-capture
  review notices. Captures remain ignored local output, not approved fixtures.
- A clean production consumer compiled the unpacked TypeSafe 0.3.0, Pristine
  0.4.0 and HTTP 0.2.0 artifacts, resolving all other dependencies from Hex,
  including execution-plane core 0.3.0. Live model listing and semantic
  evaluation, response fingerprint metadata and pre-cancelled request handling
  passed. This additional consumer ran on Elixir 1.20.3 / OTP 29.0.5.

The consumer uses unpacked artifacts for the unpublished packages; this is not
claimed as fully Hex-resolved acceptance. Live success does not prove remote
rollback or non-execution after cancellation.

## Compatibility matrix

The manual source-mode [CI run](https://github.com/nshkrdotcom/typesafe_sdk/actions/runs/35280716605)
checks the release code against explicit sibling commits:

- Pristine `8fd10288abedea3c0820015cdf796dd1dae0dc78`.
- Execution Plane `63b69ff3984f6f8440866e96a16ceee3ad73bf41`.

The hosted quality job passed (format, compile, Credo, Dialyzer, docs, freshness
and package build). The test/freshness matrix passed on all configured pairs:

- Elixir 1.18.4 / OTP 27.3.
- Elixir 1.19.5 / OTP 28.3.1.
- Elixir 1.20.4 / OTP 29.0.6.

## Sibling readiness

Both sibling commits were already pushed. Pristine root `mix ci` and runtime
`mix hex.build --unpack` passed again. The root gate uses recorded impact state
for unchanged tests; its earlier 347-test runtime acceptance remains documented
in `../pristine/HANDOFF.md`.

Execution Plane HTTP package `mix ci` passed again (**15 tests**, strict Credo,
Dialyzer and docs), followed by `mix hex.build --unpack`. Its earlier root QC,
package dry run and Hex-core consumer acceptance are documented in
`../execution_plane/protocols/execution_plane_http/RELEASE_READINESS.md`.
No sibling source changes were needed.

## Publication boundary

No tags or packages were published. The train is:

1. `execution_plane_http 0.2.0`, tag `execution_plane_http-v0.2.0`.
2. `pristine 0.4.0`, tag `pristine-v0.4.0`.
3. `typesafe_sdk 0.3.0`, tag `v0.3.0`.

Execution-plane core stays at 0.3.0; Pristine tooling packages retain their
versions. After each dependency publishes, resolve the next package against Hex
and rerun its release gate. TypeSafe's obsolete Pristine 0.3.1 and HTTP 0.1.0
lock entries were removed; publication must supply real new lock entries.

Normal push/PR CI intentionally uses Hex and cannot resolve unpublished
Pristine 0.4.0. The full `mix hex.publish --dry-run --yes` is likewise blocked
by unavailable Hex dependencies (including checkout-only maintenance tooling
when using the local packaging bootstrap). Run it with the documented
maintenance-tools-only setup after dependency publication. These are explicit
publish-train steps, not source QC successes. See `PUBLISHING.md`.

## Fixes required by executable QC

- Qualified the test transport's local `send/2` call to avoid a Kernel conflict.
- Passed cancellation tokens through Pristine's opaque-type validation API.
- Corrected three fixtures that supplied `model` as an answer key.
- Applied formatter/Credo fixes and made the public client contract type visible
  to ExDoc without exposing the internal helper module.
- Fixed the aggregate test environment and added opt-in, commit-selected source
  CI for pre-publication matrix verification.

The original static-only delivery and unexecuted TDD history are retained in
`HANDOFF.md`. No executable baseline RED run is retroactively claimed.
