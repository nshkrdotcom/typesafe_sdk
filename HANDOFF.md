# TypeSafeSDK 0.1.0 handoff

## Local completion — 2026-09-16

The SDK is implemented, generated from the live upstream OpenAPI document, and
verified against local Pristine 0.3.0. Both packages build locally. No package was
published by the agent. The owner committed and pushed the initial Pristine changes.

Toolchain: Elixir 1.19.5 / OTP 28.3.1, matching `.tool-versions` and CI.

## Verification results

| Gate | Result |
| --- | --- |
| Pristine prerequisite | Green; 315 runtime tests, format, warnings-as-errors compile, strict Credo, Dialyzer, warnings-as-errors docs, and unpacked Hex package |
| `mix deps.get` | Green with the local source configuration below |
| `mix typesafe.prereq` | Green; actual inclusive status-range capability verified |
| Live OpenAPI refresh and review | Green; same two endpoints, reviewed union and Usage changes |
| `mix typesafe.generate --project-root .` | Green; 16 generated modules and five manifests |
| `mix format --check-formatted` | Green |
| `mix compile --warnings-as-errors` | Green |
| `mix test` | 32 offline tests passed; two live tests excluded |
| Live API | Both model-list and System One tests passed with a real key; `--include live` and final `--only live` runs passed |
| `mix credo --strict` | Green |
| `mix dialyzer` | Green; zero warnings, no suppressions |
| `mix docs --warnings-as-errors` | Green |
| `mix typesafe.verify --project-root .` | Green |
| `mix hex.build --unpack` | Green; package contents reviewed |

The focused runtime tests exercise generated operations through the real Pristine
pipeline with a mocked transport: protected headers, last-write-wins extra body,
timeout units, retry attempt headers, all-5xx/default and custom status sets,
Retry-After controls, lower transport timeout/connection flags, and total retry
budgets. Existing decoder tests cover unknown answers, malformed known answers,
integer score keys, model fields, and error mappings. Live tests cover both API
operations and all three question types. Default tests make no API calls.

## Local commands

The existing `workspace_dep/1` hook remains intact. Machine-local source selection
is in `~/.config/mix_workspace_ops/typesafe_local_bootstrap.exs`, with a convenience
wrapper at `~/.local/bin/typesafe-mix`. No MWO executable or portfolio registry is
needed. No sibling paths are committed in either project's dependency tuples.

From this checkout:

```bash
~/.local/bin/typesafe-mix deps.get
~/.local/bin/typesafe-mix typesafe.prereq
~/.local/bin/typesafe-mix test
~/scripts/with_bash_secrets ~/.local/bin/typesafe-mix test --only live
~/.local/bin/typesafe-mix typesafe.verify --project-root .
~/.local/bin/typesafe-mix hex.build --unpack
```

The bootstrap selects relative paths to the three local Pristine packages and
the existing Execution Plane HTTP package. Execution Plane core resolves from
Hex at **0.3.0**, satisfying Pristine's committed `~> 0.3.0` constraint. It does
not depend on the unrelated local core 0.3.0 checkout. Packaging commands use the
ordinary committed Hex tuples.

## Pristine changes

Pristine runtime/workspace version is 0.3.0. Its provider profile supports:

```elixir
status_retry_ranges: [
  %{range: 500..599, retry?: true,
    telemetry_classification: :upstream_failure, breaker_outcome: :failure}
]
```

Exact overrides win; overlapping, descending, non-unit-step, and out-of-status
ranges are rejected. Unconfigured providers retain their behavior. The Foundation
adapter additionally supports zero backoff and an opt-in `retry_budget_ms` that
stops before an over-budget delay and returns the last result. Foundation still
owns retry orchestration.

See `../pristine/HANDOFF_TYPESAFE_0.3.0.md` for Pristine evidence. Its starting
commit was `dc54297fa04c17bc381fe068dc13158a57af9ad8`; the owner subsequently committed and pushed the runtime changes.

## Reviewed upstream differences

`priv/upstream/openapi.json` is now a live snapshot, replacing the reconstructed
Python 0.6.0 wire snapshot. The endpoint set remains `POST /v1/systemone` and
`GET /v1/models`. Named Question/Answer unions expand into the reviewed three
alternatives. Usage now requires token counts and no longer declares
`billing_units`. Python's public normalization and forward compatibility remain
in handwritten modules outside the generated tree.

The refresh task explicitly loads the provider before invoking its optional
callback, so a fresh Mix process actually fetches upstream instead of silently
regenerating the old snapshot.

## Publication handoff

Follow `PUBLISHING.md` for the minimal release sequence and exact commands:

1. `execution_plane_http 0.1.0` from its lane package directory.
2. `pristine 0.3.0` from `apps/pristine_runtime` (not the workspace root).
3. `typesafe_sdk 0.1.0` from its unpacked distribution.

Pristine Codegen and Testkit stay local. They are not runtime requirements and
are excluded from the unpacked SDK's development dependencies. HTTP's manifest
now consistently defaults to published core 0.3.0 through its `~> 0.3.0` range.
No newer core release or unrelated lane publication is needed.

The owner published the initial HTTP 0.1.0. It must now be replaced with the
updated dependencies. Final source, lockfile, and release notes are committed
and pushed; no package was published by the agent.
The remaining prerequisite for plain Hex resolution is publishing the packages
above in order, allowing the registry to catch up between uploads.

Portfolio bookkeeping adds the two library entries and the TypeSafe → Pristine
dependency to `../portfolio`; it is not involved in building or testing.

All direct dependencies and resolved graphs were refreshed on 2026-09-16.
See PUBLISHING.md for the remaining latest-Cowlib test dependency advisories
and replacement-aware commands.
