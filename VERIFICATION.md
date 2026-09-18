# TypeSafeSDK 0.4.0 verification record

Date: **2026-09-17**.

## Follow-on live-example/endpoint overlay status

The prior target-host evidence below belongs to the finalized 0.4.0 baseline at
`89086c33a6c94623289aafabd18a5cb8ede8c5e3`. A subsequent follow-on adds the
complete live-example catalog and first-class alternate-endpoint workflow. That
follow-on was authored in an environment with **no Elixir, Erlang or Mix runtime**.
It therefore does not inherit the baseline's green compile/test/live/package status.

Static checks performed for the follow-on include changed-path overlay comparison,
Bash syntax for `examples/run_all.sh`, residual hardcoded-live-endpoint/fixture
searches, generated-file diff checks, and ZIP inventory verification. No real API
credential was used and no provider-specific Cloudflare endpoint/model/auth claim
was fabricated.

The next target-host agent must run the maintenance bootstrap from
`.github/actions/setup/action.yml`, focused endpoint/example/OTP tests,
`scripts/check_handoff.sh`, schema and codegen verification, full `mix ci`, Hex
package/unpacked docs dry-run checks, then authorized live examples. Record the
actual results here before committing/pushing the follow-on branch. Do not publish
or tag during that QC pass. See `AGENT_HANDOFF_LIVE_EXAMPLES_0.4.0.md`.

## Prior finalized-baseline evidence

Local toolchain for the evidence below: **Elixir 1.19.5 / OTP 28.3.1**.

## Dependency/source evidence

Runtime dependencies resolved from published Hex packages, including
`pristine 0.4.0` and `execution_plane_http 0.2.0`. The committed runtime
requirements are unchanged. Reach 2.8.4 and its dependencies are now locked.
The unpublished `pristine_codegen` and `pristine_provider_testkit` maintenance
packages used the CI bootstrap and Pristine checkout pinned to
`04ba7b112413591f5cb9260f1d270bbbeb8a0630`; no runtime source override was used.

Inspected the published Pristine cancellation creation, validation, watch/stop
and cancellation APIs, capability discovery and existing request execution path.
The prerequisite gate and actual serialization/retry/decode tests passed against
that runtime. The original misnamed Pristine attachment was not used as evidence.

## Completed target-host gates

- Dependency resolution and `mix typesafe.prereq`.
- `mix format --check-formatted` and compilation with warnings as errors.
- Offline ExUnit: **1 doctest, 135 tests, 0 failures, 2 live tests excluded**.
- `mix credo --strict`: no issues.
- `mix reach.check --arch --smells`: architecture passed. The 18 advisory smell
  findings do not fail the configured gate; no architecture rule was relaxed.
  Source scope is explicitly `lib` and `codegen` to exclude unpacked old releases.
- `mix dialyzer`: zero errors, zero skipped warnings.
- `mix docs --warnings-as-errors`.
- Schema and codegen freshness verification, without refresh or regeneration.
- `mix hex.build --unpack`, package inventory and source byte comparison.
- `mix hex.publish --dry-run --yes` from the unpacked artifact, with a fresh
  build directory, the QC lockfile and no workspace bootstrap. Package and docs
  dry run passed; this did not publish anything.
- `mix ci`: final local aggregate passed.

The artifact contains the OTP runtime, recursive/OTP guides, live example,
committed schemas/upstream source and implementation record. It excludes
checkout maintenance code, tests, `.reach.exs`, credentials and build artifacts.
Only Pristine, Jason and Telemetry appear as Hex runtime requirements.
See `PUBLISHING.md` for the unpacked-artifact publication procedure; running the
combined publish/docs task from the checkout requires unpublished tooling.

## Live evidence

With the explicit host credential, `mix test --include live --warnings-as-errors`
passed: **1 doctest, 137 tests, 0 failures**, including real model listing and
System One requests. Both requested live examples also passed:

- `examples/live_observability.exs`: start -> answer -> stop events, model
  `jev-1.13.0`, real usage/request metadata and Pristine capability discovery.
- `examples/live_recursive_decisions.exs`: two-level descent returned
  `%{branch: :billing, leaf: :invoice}`.

These checks do not establish transport queue bounds, calibration or remote
non-execution after cancellation.

## Issues resolved during QC

- Completed cancellation watcher messages no longer get consumed and then awaited
  again forever during OTP request cleanup.
- Worker exits cancel the private request token and return a typed task-exit
  error; caller tokens remain caller-owned.
- Unsupported cancellation capabilities become typed SDK errors, preserving the
  OTP callback error contract.
- Fixed formatting, Credo findings, hidden ExDoc reference, changelog heading
  assertion and linked-start failure handling in the missing-supervisor test.
- Added worker-exception, pending-status privacy, unsupported-capability and
  future-answer telemetry/projection regression coverage, including event order.

## Publication boundary

Hex publication and creation/push of `v0.4.0` are intentionally pending.
The normal push-triggered GitHub CI matrix must pass for the final commit before
publication; use the exact commit's run, without runtime source-ref overrides.