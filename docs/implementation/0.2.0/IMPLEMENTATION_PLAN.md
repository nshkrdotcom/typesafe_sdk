# Implementation plan

## Sequence (one change set, tests accompany each step)

1. Reconstruct the 97-file baseline from typesafe_sdk(2).xml. Inventory all three
   comparison repositories and discussion docs. Keep baseline separate to build
   a changed-path-only overlay. Inspect runtime availability and record facts.
2. Write constructor/JSON/prepared regression tests first. Implement strict
   Question.* modules, validation paths, JSON normalization, ordered Choice
   encoding, finite key registries, extras and prepared sets. Add delegates to
   the public facade without replacing legacy constructors.
3. Write relational response and uncertainty-helper tests. Extend existing
   answer/response structs; implement response enrichment, domain/range/sum
   validation, forward-compatible unknowns and raw preservation. Implement
   lookup/filtering, ranked/margin/normalized/expected/modal helpers and explicit
   policy gating. Keep system_one wire identity behavior.
4. Write execution/option/telemetry integration tests using the real Pristine
   transport seam. Implement Evaluation orchestration and semantic telemetry.
   Add retryability query and runtime-capability audit. Test protected extras,
   validation before HTTP, privacy, metadata preservation and semantic failures.
5. Write batch concurrency/order/timeout/crash/early-halt tests. Implement
   per-enumeration owned Task.Supervisor lifecycle and lazy stream continuation;
   collect with evaluate_many. Reuse Prepared without revalidation per state.
6. Write consumer fixture contract and sequence tests. Implement Test.Scenario,
   Test.Transport and public Test helpers. Capture real serialized requests,
   enforce fixture contracts, synthesize distributions, expose metadata and
   bounded history. Exercise actual retries with 529 -> 529 -> 200.
7. Add schema exporter/checker and committed exports derived from the bounded
   source. Add self-contained ref/round-trip/freshness tests. Do not alter
   generated request contracts or fingerprints unnecessarily.
8. Implement labeled evaluation example, loader/policy/metrics/report/sweeps and
   dataset tests. Add guides and cheatsheet with executable test examples.
9. Update version source, package/doc registrations, README and existing guides,
   CHANGELOG, PORT_PARITY, publishing and agent instructions. CI covers the
   claimed compatibility pairs; live CI is explicitly opt-in and captures only
   synthetic requests. Add target-host check script and actual handoff.
10. Run all available checks, perform source-level integration review, compare
    overlay files against baseline, verify ZIP paths and contents. Deliver the
    docset and overlay separately. Never claim unexecuted BEAM/live gates passed.

## File boundaries

New library areas: json.ex; question/{noul,choice,score}.ex; question/validation.ex;
prepared.ex; semantic_response.ex; evaluation.ex; batch.ex; answer.ex and
answer/{noul,choice,score}.ex; response.ex; telemetry.ex; runtime_capabilities.ex;
test.ex and test/{scenario,transport}.ex; schema.ex. Mix tasks for schema
export/verify, runtime audit and synthetic live capture. Existing public answer
and response modules receive additive fields; error and public facade get new
APIs; client changes are limited to declared runtime requirements.

Tests are divided into pure contracts, transport-integrated semantic execution,
batch lifecycle, fixture contracts, schemas, evaluation example and release
consistency. Existing tests remain as regression coverage. There is no removal
phase and no upstream prerequisite implementation hidden in the SDK overlay.
