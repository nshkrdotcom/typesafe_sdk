# Changelog

## [0.4.0] - 2026-09-17

### Added

- `TypeSafeSDK.Response.values/1`, a narrow primary-value projection that preserves
  caller keys without introducing a second response hierarchy.
- Privacy-safe `[:typesafe_sdk, :answer]` telemetry after semantic validation, with
  confidence/distribution-shape measurements, question ordinal, model/request IDs
  and Prepared fingerprint but no state, question IDs/text, selected labels, raw
  bodies, credentials, Noul direction or Score values.
- `TypeSafeSDK.OTP.Server`, an opt-in bounded GenServer facade for non-blocking
  semantic work using a caller-owned `Task.Supervisor`, per-server `max_in_flight`,
  typed SDK results and Pristine cancellation. No global SDK process was added.
- Recursive-decision documentation and a live two-level descent example covering
  hierarchical descent, bisection, verify/repair, coarse-to-fine cascades and
  bounded clarifying loops.
- Reach architecture boundaries plus CI/handoff gates preventing handwritten pure
  semantic modules from reaching runtime/orchestration layers and runtime
  integration from reaching upward into orchestration.
- 0.4 migration, OTP integration and implementation-record documentation; Jev is
  credited in README for the OTP/recursive/telemetry/architecture inspiration.

### Changed

- Bumped package/runtime/header/docs/schema release metadata to 0.4.0 while keeping
  the generated OpenAPI operations and existing Pristine runtime boundary intact.
- `mix ci`, GitHub quality CI and `scripts/check_handoff.sh` now include
  `mix reach.check --arch --smells`.

### Fixed

- Handle completed OTP cancellation watchers without hanging request cleanup;
  cancel private request tokens when evaluation workers exit.
- Normalize unsupported transport cancellation into typed SDK errors so OTP
  consumers retain the documented error contract.
- Restrict Reach source discovery to current runtime and maintenance source,
  excluding unpacked historical release artifacts.

### Verification status

- Target-host compilation, tests, static analysis, documentation, schema/codegen
  freshness and package build passed against published Pristine 0.4.0.
- Live model listing, System One, answer telemetry and recursive decision examples
  passed. See `VERIFICATION.md` for release QC details.

## [0.3.0] - 2026-09-17

### Added

- Verified unary cancellation forwarding with `Pristine.Cancellation`, typed
  cancellation preservation, and Pristine-owned capability discovery for
  `:unary_cancellation` and `:cancellation_cleanup`.
- Cancellation-aware bounded batch scheduling: one shared token is forwarded to
  started requests and no additional work is scheduled after cancellation is
  observed; existing task/lifecycle cleanup remains authoritative.
- Client-level retry defaults with structural per-call inheritance/override and
  explicit `false` disable semantics, still executed entirely by Pristine.
- Immutable Prepared composition (`keys/1`, `put/3`, `delete/2`, `take/2`,
  `merge/2`) with validation on every rebuild and deterministic execution order.
- Versioned `typesafe-prepared-v1:<sha256>` semantic-contract fingerprints and
  response/error fingerprint propagation.
- Opt-in strict response contracts for unknown answer keys and exact allowed-model
  membership, preserving 0.2 behavior by default.
- Optional serialized request-byte budgets enforced before Pristine transport
  egress, with safe actual/limit metadata and per-call override support.
- Pure exact model lookup and objective `release_date` latest-selection helpers,
  including explicit ambiguity/unordered-catalog errors instead of fuzzy guesses.
- Stable privacy-safe `TypeSafeSDK.Response.metadata/1` and
  `TypeSafeSDK.Error.metadata/1` accessors.

### Changed

- Require Pristine `~> 0.4.0`; TypeSafe delegates runtime cancellation capability
  discovery to `Pristine.RuntimeCapabilities.transport/1` and does not infer
  support from adapter names or optional callback presence.
- Bumped package, runtime/header, docs source-ref and committed schema release
  metadata to 0.3.0.
- Preserved the 0.2 semantic constructors, enriched answers, raw/wire escape
  hatches, bounded batching, test seam, telemetry, schema tooling and evaluation
  workflow without adding an HTTP client, retry engine, circuit breaker, queue,
  or transport cancellation implementation to TypeSafe.

### Verification status

- Source/static inspection and overlay-diff checks for this implementation were
  run in the delivery environment. That environment does not provide Elixir,
  Erlang or Mix, so compilation, ExUnit, formatter, Credo, Dialyzer, ExDoc,
  generated-artifact verification, live fixtures and Hex build remain explicit
  target-environment gates. See `HANDOFF.md` and `VERIFICATION.md`.

## [0.2.0] - 2026-09-17

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


## [0.1.2] - 2026-09-16

### Improved

- Expanded README with comprehensive System One decision model guides, typed question
  workflows, and SDK architecture documentation.

## [0.1.1] - 2026-09-16

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

## [0.1.0] - 2026-09-16

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

[0.4.0]: https://github.com/nshkrdotcom/typesafe_sdk/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/nshkrdotcom/typesafe_sdk/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/nshkrdotcom/typesafe_sdk/compare/v0.1.2...v0.2.0
[0.1.2]: https://github.com/nshkrdotcom/typesafe_sdk/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/nshkrdotcom/typesafe_sdk/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/nshkrdotcom/typesafe_sdk/releases/tag/v0.1.0
