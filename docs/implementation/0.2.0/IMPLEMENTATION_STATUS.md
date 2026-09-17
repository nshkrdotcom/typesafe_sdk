# Implementation status: TypeSafeSDK 0.2.0

Release date: **2026-09-16**. The implementation uses typesafe_sdk(2).xml as its
only baseline. The separate overlay contains the actual library changes, tests,
schemas, CI configuration, examples, documentation and final HANDOFF.md.

## Implemented feature families

| Feature family | Implementation |
| --- | --- |
| Strict questions and structured validation | Question.Noul/Choice/Score, Question.Validation, JSON, Prepared |
| Caller identity, request-relative validation and raw fidelity | SemanticResponse; existing response/answer types enriched additively |
| Uncertainty and response ergonomics | Answer, Answer.Noul/Choice/Score, Response; fetch/filter helpers |
| Evaluation and bounded batch lifecycle | Evaluation, Batch, Batch.Lifecycle; same Generated/Client/Pristine execution path |
| Consumer testing through production serialization/retries/decoding | Test, Test.Scenario/Transport/Fixture/ContractError |
| Observability and operational requirements | Telemetry, Error retry helpers, RuntimeCapabilities, capability task |
| Authoritative JSON Schema distribution | Schema, export/verify tasks, three committed exports |
| Labeled model/policy evaluation | Runnable example, development/held-out datasets, threshold sweeps and frozen policies |
| Release and maintainability | Version 0.2.0, dated changelog, migration/guides/cheatsheet, CI matrix and opt-in live capture |

Ordered batches additionally bound source prefetch and completed-result storage
with finite windows rather than claiming that a task-count bound limits all
buffering. Escaping worker failures are normalized without raw crash content.

The implementation also checks malformed headers, improper lists, normalized-key
collisions, dotted IDs and unknown future answers. Failed development policy
selection persists the observations instead of discarding them or silently
choosing fallback thresholds. Incomplete development runs do not freeze policy.

## Verification boundary

The delivery environment has no Elixir/Erlang/Mix installation. The implementation
includes ExUnit regression and transport-integrated tests, but no BEAM test pass,
compiler pass, formatting pass, Credo/Dialyzer pass, ExDoc/package build, live
result or generated-artifact verification is claimed. Tests were supplied and
source-reviewed; an executed red/green TDD cycle was not available here.

Python-based delivery checks cover source lexical/block/delimiter screening,
JSON and YAML parsing, authoritative schema derivation and reference resolution,
dataset contracts, relative documentation links, preserved generated/upstream
files, preserved license/artwork, version consistency and overlay reproduction.
They are not substitutes for Elixir parsing, compilation or ExUnit. The overlay's
HANDOFF.md and VERIFICATION.md record the actual results and target-host steps.

## Deliberately not moved into this SDK

Generic HTTP pools, global queues, streaming body limits and physical request
cancellation remain Pristine/transport responsibilities. The SDK implements an
honest capability audit and fail-closed declared requirements, not fictional
runtime guarantees. A transport advertisement still needs real contract tests.
No second HTTP/retry stack, speculative model-quality claims, or fabricated live
recordings were added.
