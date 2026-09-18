# TypeSafe SDK 0.4.0 implementation record

Release target: **0.4.0** (2026-09-17).

This release selectively incorporates ideas observed in `dannote/jev` without
replacing TypeSafeSDK's architecture. The implementation adds:

- executable source architecture boundaries with Reach;
- privacy-safe per-answer telemetry after semantic validation;
- `TypeSafeSDK.Response.values/1` as a narrow primary-value projection;
- recursive decision pattern documentation; and
- an opt-in bounded `TypeSafeSDK.OTP.Server` that uses a caller-owned
  `Task.Supervisor`, existing TypeSafe clients/responses, and Pristine
  cancellation rather than a package-global supervisor or second HTTP stack.

The generated OpenAPI surface is unchanged. Pristine remains the only
HTTP/resilience runtime. The 0.3 cancellation, retry, Prepared fingerprint,
response-contract, request-budget, model-helper, batching, testing, and schema
contracts remain in place.

## Target-host finalization

The original `pristine_sdk.xml` attachment duplicated the TypeSafeSDK baseline.
Finalization instead verified cancellation, capability discovery and execution
contracts directly against published Hex Pristine 0.4.0. Runtime dependencies
remain Hex packages; the two unpublished maintenance tools use CI's pinned
Pristine source checkout.

QC fixed completed-watcher cleanup, worker-exit token cancellation and typed
unsupported-cancellation errors. It also resolved formatting, static analysis,
documentation and release-consistency failures. Reach source scope is explicitly
`lib` and `codegen`, preserving the architecture rules while excluding unpacked
historical artifacts. Regression coverage includes worker exceptions, pending
status privacy and future-answer telemetry/projection behavior.

## Live examples and alternate-endpoint follow-on

Before the same 0.4.0 release is tagged or published, a follow-on completes the
runnable live-example catalog for the public 0.2-0.4 surface and makes alternate
TypeSafe-compatible API roots a first-class onboarding workflow. The shared live
helper, evaluation CLI, recorder, scheduled live capture and all-examples runner
now honor the selected endpoint/model while retaining the real Pristine HTTP path
and retry-disabled general examples. Handwritten client validation rejects blank
or credential-bearing/query/fragment base URLs while retaining deployment path
prefixes for generated `/v1/*` operations.

Focused examples cover Prepared composition/fingerprints, model catalog helpers,
strict response contracts, request-byte budgets, runtime controls/cancellation,
all three answer telemetry families and real `TypeSafeSDK.OTP.Server` integration.
The recursive example now executes all five documented bounded patterns. The
example catalog distinguishes live demonstrations from guarantees that can only
be asserted deterministically in tests/tooling.

The follow-on was initially authored in an environment without Elixir/Erlang/Mix,
but target-host finalization is now complete. The release-candidate implementation
passed formatter/compile/tests, strict Credo, Reach, Dialyzer, warnings-as-errors
docs, schema/codegen freshness, package build/dry-run, live-inclusive ExUnit, the
complete live example/evaluation surface, and the normal push-triggered GitHub CI
matrix. The live pass exposed and resolved two example-only defects: invalid
same-pattern pinning in the OTP example and non-JSON state values in recursive
bisection/verification.

No third-party provider URL/auth/model compatibility is claimed without a supplied
and authorized deployment. See `HANDOFF.md` and `VERIFICATION.md` for executed
evidence, `AGENT_HANDOFF_LIVE_EXAMPLES_0.4.0.md` for the completed follow-on record,
and `PUBLISHING.md` / `scripts/release_qc.sh` for the durable release procedure.
Publication and tagging remain separate release steps.
