# TypeSafeSDK 0.2.0 implementation docset

Release date: **2026-09-17**. Baseline: **typesafe_sdk(2).xml** only.

Read SPECIFICATION.md, then IMPLEMENTATION_PLAN.md. SOURCES_AND_DECISIONS.md
records where the ideas came from and resolves contradictions between the three
discussions. ACCEPTANCE.md defines the tests and release gates. The implementation
overlay contains the final HANDOFF.md with observed verification results.

This is an implementation specification, not a proposal for a later phase. Build
the selected SDK features completely, retain the existing generated/Pristine
execution path, and make the release/doc/test changes in the same change set.
Do not substitute fixture-only implementations for production calls. The explicit
consumer testing facade is a test transport, never a production backend.

## Deliverables

1. This small planning archive.
2. A repository-root ZIP overlay containing only added/changed paths, including
   tests, guides, examples, schemas, CHANGELOG.md, and HANDOFF.md. No deletions,
   dependency directories, generated BEAM binaries, or invented live recordings.

The release is not represented as verified until the full target-environment
checks pass. Environment limitations do not reduce the implementation scope.
