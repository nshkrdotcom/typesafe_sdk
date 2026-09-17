# Runtime controls and semantic contracts

TypeSafe SDK 0.3.0 adds caller-facing controls while keeping Pristine as the
single HTTP/resilience runtime. The authoritative migration examples and
compatibility notes are in [Migrating from 0.2.x to 0.3.0](migration-0.3.md).

## Ownership boundary

TypeSafe owns semantic construction/validation, Prepared composition and
fingerprints, response-contract interpretation, request-size preflight, model
catalog helpers and privacy-safe metadata. Pristine owns transport execution,
physical unary cancellation, retry execution/waits, rate limits, circuit
breakers and runtime capability discovery.

This boundary is intentional: there is no TypeSafe HTTP pool, retry loop,
circuit breaker, global queue or transport cancellation engine.

## New call options

Semantic unary calls accept `cancellation:`, `response_contract:` and
`max_request_bytes:` alongside the existing timeout/retry/header options.
`system_one/4` accepts cancellation and the local request-byte budget while
preserving its raw/parity response behavior. `list_models/2` forwards unary
runtime options, including cancellation, through the same generated/Pristine
path.

## Metadata and privacy

Use `TypeSafeSDK.Response.metadata/1` and `TypeSafeSDK.Error.metadata/1` when
instrumentation needs stable fields. Do not log the response/error struct itself
when its raw-body fields may contain application data.
