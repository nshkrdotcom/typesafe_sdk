# TypeSafe SDK 0.3.0 implementation record

TypeSafe SDK 0.3.0 extends the 0.2 semantic layer without moving HTTP/runtime
ownership out of Pristine. The release adds verified Pristine cancellation
forwarding and capability inspection, cancellation-aware bounded batches, retry
inheritance/merge, Prepared composition and semantic fingerprints, opt-in strict
response contracts, local serialized-request byte budgets, pure model catalog
helpers, and stable privacy-safe response/error metadata.

Runtime prerequisite: **Pristine `~> 0.4.0`**. Cancellation tokens are
`Pristine.Cancellation` values and physical unary cancellation remains a Pristine
transport capability. TypeSafe does not implement an HTTP pool, retry loop,
circuit breaker, or competing cancellation engine.

See `guides/migration-0.3.md`, `CHANGELOG.md`, `HANDOFF.md`, and
`VERIFICATION.md` for release usage, compatibility, and verification state.
