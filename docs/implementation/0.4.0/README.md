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

See `HANDOFF.md` and `VERIFICATION.md` for gate results. Publication and tagging
remain separate release steps.
