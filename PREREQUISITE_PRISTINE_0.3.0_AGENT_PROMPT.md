# Agent prompt — implement the Pristine prerequisite first

Implement **only** the tightly scoped Pristine 0.3.0 prerequisite described in
`PREREQUISITE_PRISTINE_0.3.0.md` against the supplied Pristine repo.

Use TDD and the repo's real runtime/classifier paths. Add the first-class
`Pristine.SDK.ProviderProfile.status_retry_ranges` contract exactly as specified,
with exact-status precedence, deterministic validation, no TypeSafe-specific
branching, and no global change making all 5xx retryable. Bump the Pristine
workspace/runtime release from 0.2.1 to **0.3.0**, date the release entries
**2026-09-16**, update all affected runtime dependency docs/constraints, preserve
`Unreleased`, run the full repo QC/package gates, and leave a concise handoff with
commit SHA and gate results.

Do not work on `typesafe_sdk` in this pass. The TypeSafe repo deliberately depends
on `pristine ~> 0.3.0`; return to it only after this prerequisite is green.
