# Changelog

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
