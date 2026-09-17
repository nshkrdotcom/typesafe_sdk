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

## Source limitation in this implementation session

The file supplied as the final `pristine_sdk.xml` was byte-for-byte identical to
the TypeSafeSDK 0.3.0 Repomix baseline (`sha256
c3279fb98ae60f9a0920ef48e5d8fd7332f3fd37bb379361b3817bae8b4bca0a`). It did
not contain a distinct Pristine repository. Therefore no new Pristine API claim
was inferred from that attachment. The implementation uses only the Pristine
contracts already consumed by the baseline (`Pristine.Cancellation`, the existing
client/runtime execution path, and runtime capability delegation). A target-host
agent must replace/verify this assumption against the intended final Pristine
source before release.

See `HANDOFF.md` and `VERIFICATION.md` for required target-host gates.
