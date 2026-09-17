# Changelog

## 0.2.0 - 2026-09-17

### Added

- Strict semantic question constructors with tuple/bang forms, top-level helpers,
  structured JSON descriptions, ordered Choice options, Score labels, protected
  extras and path-aware local validation.
- Prepared question sets with cached JSON and finite caller-key restoration;
  evaluate/evaluate!, evaluate_many/evaluate_stream and system_one! conveniences.
- Request-relative answer validation for IDs, types, selected options,
  probability domains/sums, Score ranges/rubrics and nonnegative usage.
- Raw response/answer retention, unknown_answers, semantic IDs/rubrics/labels,
  runtime and logical elapsed time, retry counts and batch input indexes on the
  existing response/answer structs; no duplicate Result hierarchy.
- Answer ranking, Choice margin, expected/modal/normalized Score helpers, Noul
  decisions/certainty, explicit-threshold gates and response fetch/filter helpers.
- Unlinked supervised batch workers, monitored per-enumeration ownership,
  bounded concurrency and ordered prefetch windows, explicit task/attempt budgets, collect/raise failures and
  early-halt/caller-exit cleanup.
- Application test client at the Pristine transport seam with exact/synthetic
  distributions, request-contract checking, errors/models, finite sequences,
  state-dependent callbacks, metadata, verification and bounded request history.
- Privacy-oriented semantic telemetry, nested caller metadata and public
  retryability/Retry-After helpers.
- Fail-closed runtime-capability auditing. Unadvertised transport bounds remain
  unverified; no second HTTP stack, global pool or pretend streaming body cap.
- Authoritative OpenAPI-derived self-contained JSON Schema export/verification.
- Runnable synthetic support-triage evaluation with separate model/policy metrics,
  development-only threshold sweeps, frozen held-out policies, ambiguous labels,
  coverage/error/review/latency/token reporting and provenance metadata.
- Live-only runnable examples for semantic answers, batching, telemetry/runtime
  inspection, composite scoring and speculative model lookup, with one complete
  example runner and an expanded coverage catalog.
- Semantic, migration, testing, uncertainty, batch, telemetry, schema, runtime and
  decision-pattern guides; cheatsheet; compatibility-matrix CI; opt-in real live
  capture/diffs without fabricated recordings or automatic commits.

### Changed

- Require Pristine ~> 0.3.1, carrying Foundation 0.2.2's supervised ETS registry
  ownership fix and removal of unexpected `ETS-TRANSFER` logs.
- Aligned Mix package and runtime/header version reporting at 0.2.0.
- Strengthened known wire probability/usage validation and collision detection.
- Added strict semantic header validation, improper-list rejection and response
  path components that preserve dotted caller IDs.
- Retained existing legacy constructors, string-keyed system_one behavior,
  protected headers, raw extras, retry defaults, Pristine runtime ownership and generated
  operation/schema ownership. Added telemetry as a directly used dependency.
- Updated package/HexDocs registrations, contributor and publishing instructions,
  offline gates and target-environment handoff. Generated wire artifacts and
  historical dependency/upstream versions are unchanged.

### Verification status

- Native compilation, formatting, ExUnit (including live tests), strict Credo,
  Dialyzer, ExDoc, schema/codegen verification and Hex packaging passed. The
  three-pair Elixir/OTP CI matrix is green. See HANDOFF.md and VERIFICATION.md
  for execution evidence; this is not a claim of Hex publication.


## 0.1.2 - 2026-09-16

### Improved

- Expanded README with comprehensive System One decision model guides, typed question
  workflows, and SDK architecture documentation.

## 0.1.1 - 2026-09-16

### Added

- Runnable live API example showing model metadata, typed questions, structured
  answers, probabilities, confidence, and token usage; included in the Hex package.
- Guide index and organized documentation menus for getting started, usage,
  examples, maintenance, and project information.
- MIT License page in the documentation navigation and grouped API module reference.

### Improved

- Expanded installation, configuration, response handling, and question guides.
- Corrected the documented Noul criteria shape and minimum of two score levels.
- Updated publishing instructions for the standalone 0.1.1 SDK patch release.

## 0.1.0 - 2026-09-16

- Refresh all direct dependency requirements to current stable releases and update
  the complete resolved dependency graph (2026-09-16).

- Initial ground-up Elixir port of the supplied TypeSafe Python SDK 0.6.0.
- Added System One and model-list operations.
- Added noul, choice, and score question/answer types.
- Added Python-compatible response/error normalization and retry defaults.
- Preserved successful-response request IDs/raw Pristine responses and attached the same metadata to response-validation failures.
- Added Pristine runtime integration and PristineCodegen provider/source plugin.
- Added committed live OpenAPI snapshot and deterministic refresh/generate/verify tasks.
- Added pure contract tests and opt-in real API integration tests.
- Added handoff and maintenance documentation.
- Keep checkout-only generation/test tooling out of the unpacked release dependencies;
  publishing the SDK does not require publishing Pristine Codegen or Testkit.
- Made Pristine 0.3.0 a hard prerequisite and consume its first-class provider
  HTTP status-range override contract for the Python SDK's `500..599` retry rule.
- Reviewed live Question/Answer unions and token-only Usage schema against Python 0.6.0.
- Verified both real API operations and the generated request pipeline.
- Corrected total retry budgets, zero backoff, and lower transport timeout classification.
- Hardened OpenAPI refresh TLS verification and removed dynamic HTTP-method atom
  conversion from the source plugin.
- Made per-call retry status sets and `respect_retry_after` affect actual Pristine
  classification, not only Foundation backoff options.
