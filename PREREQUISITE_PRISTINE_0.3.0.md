# Pristine 0.3.0 prerequisite for TypeSafeSDK

## Purpose

`typesafe_sdk` must not work around Pristine's current HTTP status classifier.
Before the TypeSafeSDK completion/QC pass, Pristine must gain a first-class,
provider-owned way to declare retry/classification behavior for an inclusive
HTTP status range.

The concrete motivating contract is the supplied TypeSafe Python SDK 0.6.0,
whose default retry set is:

- `408`
- `429`
- every HTTP status from `500` through `599`, inclusive

Pristine 0.2.1 has exact `status_retry_overrides`, while its generic classifier
has a small fixed upstream-failure set. TypeSafeSDK must not encode one hundred
integer overrides merely to express the semantic rule "all 5xx".

This change is a prerequisite, not a parallel task. Finish and QC Pristine
0.3.0 first. Then return to the TypeSafeSDK repo in this package.

## Required release

Release the Pristine runtime as **0.3.0**.

The current supplied runtime/workspace version is 0.2.1, so this is the required
`0.x++.0` minor release for the new provider-profile contract.

Release date for changelogs: **2026-09-16**.

At minimum update all of the following release coordinates and references:

- root `mix.exs`: workspace `@version` -> `0.3.0`
- `apps/pristine_runtime/mix.exs`: runtime `@version` -> `0.3.0`
- root `mix.exs`: the workspace dependency on `:pristine` -> `~> 0.3.0`
- `apps/pristine_codegen/mix.exs`: its dependency on `:pristine` -> `~> 0.3.0`
- every Pristine-owned README/guide dependency example that still instructs a
  consumer to use `{:pristine, "~> 0.2.1"}` -> `~> 0.3.0`
- root `CHANGELOG.md`: add `0.3.0 - 2026-09-16`
- `apps/pristine_runtime/CHANGELOG.md`: add `0.3.0 - 2026-09-16`

Do **not** mechanically bump `pristine_codegen` or
`pristine_provider_testkit` package versions merely because their dependency
constraint changes. Their package versions should change only if their own
published API/artifacts change under the repo's existing release rules.

Preserve any existing `Unreleased` section above the new release entry.

## Required public contract

Extend `Pristine.SDK.ProviderProfile` with a new field named exactly:

```elixir
status_retry_ranges
```

The provider-facing shape must be a list of range override entries. The intended
usage is:

```elixir
status_retry_ranges: [
  %{
    range: 500..599,
    retry?: true,
    telemetry_classification: :upstream_failure,
    breaker_outcome: :failure
  }
]
```

Each range entry consists of:

- required `:range` containing an integer `Range`
- the same optional override keys already supported by one exact
  `status_retry_overrides` entry:
  - `:retry?`
  - `:retry_groups`
  - `:telemetry_classification`
  - `:breaker_outcome`
  - `:limiter_backoff_ms`

Keep `status_retry_overrides` fully backward compatible.

## Lookup semantics

The existing public helper `Pristine.SDK.ProviderProfile.status_retry_override/2`
must resolve an HTTP status using this precedence:

1. exact `status_retry_overrides[status]`
2. one matching `status_retry_ranges` entry
3. `nil`, preserving the classifier's existing fallback behavior

This lets existing `Pristine.Adapters.ResultClassifier.HTTP` continue using its
current override path. Do not add a provider-specific TypeSafe branch to the
classifier.

Exact-over-range precedence is required so a provider can declare a broad range
and still surgically specialize one status.

## Validation and determinism

`ProviderProfile.new/1` and `new!/1` must normalize/validate the new field at
construction time.

Required rules:

- default is `[]`
- entries must be maps
- `:range` must be an integer `Range`
- only ascending, inclusive, unit-step ranges are accepted for this contract
- endpoints must be valid HTTP status integers (`100..599`)
- override keys use the exact same normalization/validation rules as exact
  status overrides
- range entries must not overlap each other
- overlapping ranges are rejected rather than resolved by declaration order
- exact status overrides are allowed to fall inside a range because their
  precedence is explicit
- no remote/user string is converted into a new atom

Error values/messages may follow current Pristine conventions; tests should
assert stable reason structure where the repo already does so.

## Classifier behavior

Do **not** globally redefine every 5xx response as retryable.

The new capability is provider-controlled. Existing providers that do not set
`status_retry_ranges` must retain their current behavior.

When a matching range entry is returned by `status_retry_override/2`, the
existing override classifier path must apply it exactly as though it had come
from `status_retry_overrides`.

For the TypeSafe example above, statuses including `501`, `505`, `520`, and
`599` must therefore be classified with:

- `retry? == true`
- telemetry classification `:upstream_failure`
- breaker outcome `:failure`

No changes are requested to the generic hard-coded failure list in this task.
The range override is the provider-level mechanism that avoids expanding that
list or making global policy assumptions.

## Required implementation scope

Keep the implementation narrow. Expected production touch point:

- `apps/pristine_runtime/lib/pristine/sdk/provider_profile.ex`

A small supporting change elsewhere in `pristine_runtime` is acceptable only if
needed to preserve the public contract above. Prefer making
`status_retry_override/2` perform exact-then-range resolution so the HTTP
classifier remains unaware of the new representation.

Do not:

- add TypeSafe-specific code to Pristine
- introduce a second retry engine
- replace Foundation retry behavior
- change generic provider defaults
- make all 5xx globally retryable
- add a dynamic-atom parser
- broaden this task into a retry-system redesign

## Required tests — TDD

Add tests before/with the implementation. At minimum prove all of these:

1. `ProviderProfile.new!/1` defaults `status_retry_ranges` to `[]`.
2. A `500..599` range is accepted.
3. `status_retry_override(profile, 500)` resolves the range override.
4. `status_retry_override(profile, 550)` resolves the same range override.
5. `status_retry_override(profile, 599)` resolves the same range override.
6. `499` and `600` do not match.
7. An exact `503` override wins over the `500..599` range.
8. Two overlapping ranges are rejected.
9. A descending/non-unit-step/invalid-status range is rejected.
10. Existing exact override behavior remains unchanged.
11. `Pristine.Adapters.ResultClassifier.HTTP` with a provider profile containing
    the range marks representative `501`, `505`, `520`, and `599` responses
    retryable with the configured telemetry/breaker fields.
12. The same statuses preserve pre-0.3 behavior when no range is configured.
13. A range entry with `retry?: false` can explicitly make a matching built-in
    failure status non-retryable through the normal override path.

Use the repo's real test infrastructure. Do not add mocks merely to prove the
shape if an existing real classifier unit/integration path can exercise it.

## Documentation requirements

Document the new provider-profile option in the runtime-facing provider/retry
configuration documentation and include one range example. Keep the explanation
provider-neutral; TypeSafe may be mentioned only as motivating downstream
compatibility, not embedded as a runtime special case.

Update all Pristine dependency snippets affected by the 0.3.0 runtime release.

The root and runtime changelogs should state, in substance:

- Added provider-defined HTTP status range overrides.
- Exact status overrides take precedence over range overrides.
- Existing provider behavior is unchanged when no ranges are configured.

## QC / release gates

Follow the supplied Pristine repo's existing AGENTS/release rules. The required
minimum gates are:

```bash
mix deps.get
mix format --check-formatted
mix compile --warnings-as-errors
mix test
mix credo --strict
mix dialyzer
mix docs
```

Prefer the repo's root aggregate gate (`mix ci`) when it covers these.

Also build the publishable runtime package from `apps/pristine_runtime` using the
repo's established isolated/package workflow and verify the unpacked Hex
contents. Do not declare this prerequisite complete while tests or package/docs
gates are red.

## Handoff evidence back to TypeSafeSDK

Before beginning TypeSafeSDK completion, capture all of the following in the
Pristine handoff/commit:

- the final commit SHA
- confirmation that runtime version is `0.3.0`
- the exact new `status_retry_ranges` contract
- green test/QC output summary
- package build result

Then run the TypeSafeSDK gates. The TypeSafeSDK code in this package already
assumes the 0.3.0 contract and must not be rewritten back to a synthesized
100-status workaround.

## Definition of done

The prerequisite is complete only when a downstream app can write:

```elixir
Pristine.SDK.ProviderProfile.new!(
  provider: :example,
  retryable_groups: [],
  status_retry_ranges: [
    %{
      range: 500..599,
      retry?: true,
      telemetry_classification: :upstream_failure,
      breaker_outcome: :failure
    }
  ]
)
```

and `Pristine.SDK.ProviderProfile.status_retry_override/2` resolves any status in
that range, while exact overrides take precedence and providers without ranges
remain behaviorally unchanged.
