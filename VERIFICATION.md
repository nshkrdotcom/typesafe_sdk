# TypeSafeSDK 0.3.0 verification record

Release date: **2026-09-17**. Baseline: the supplied complete TypeSafeSDK 0.2.0
Repomix source. Runtime reference: the supplied Pristine 0.4.0 source.

This record distinguishes source/static checks executed in the delivery container
from BEAM checks that could not run there. The container has Git, Bash, Python,
Zip and Unzip, but **does not have `elixir`, `erl`, or `mix`**. No claim of
compilation, ExUnit success, formatting, Credo, Dialyzer, ExDoc, codegen
freshness, live acceptance, or Hex-package success is made here.

## Implemented release surface

The source change set covers all required 0.3.0 areas:

- direct `Pristine.Cancellation` forwarding and cancellation-distinct errors;
- fail-closed `Pristine.RuntimeCapabilities.transport/1` delegation;
- shared-token bounded batch cancellation and existing lifecycle cleanup;
- client/per-call retry inheritance with Pristine retaining retry execution;
- Prepared `keys/1`, `put/3`, `delete/2`, `take/2`, `merge/2` composition;
- versioned `typesafe-prepared-v1:<sha256>` semantic fingerprints;
- opt-in strict response contracts;
- pre-egress serialized JSON request-byte budgets;
- exact/objective pure model catalog helpers; and
- stable privacy-safe response/error metadata.

The implementation does not add a TypeSafe HTTP dependency, retry loop, circuit
breaker, global queue, physical cancellation transport, fuzzy model lookup,
automatic probability renormalization, or a second result hierarchy.

## Checks executed in the delivery container

The following checks were actually executed against the working tree:

- `git diff --check` — exit 0.
- `bash -n scripts/check_handoff.sh` — exit 0.
- `bash -n examples/run_all.sh` — exit 0.
- Parsed every repository `.json` file and every nonblank `.jsonl` row with
  Python's JSON parser — no parse failures.
- Verified release surfaces: Mix/project version 0.3.0, public SDK version 0.3.0,
  Pristine requirement `~> 0.4.0`, all three exported schema release markers
  0.3.0, and the 2026-09-17 changelog entry.
- Screened required 0.3 API markers for Prepared composition/fingerprint, retry
  merge, cancellation, Pristine capability delegation, request budgets, response
  contracts, model helpers, and response/error metadata — all present.
- Screened `mix.exs` for a newly introduced Finch/Mint/Req/HTTPoison/Hackney or
  direct `execution_plane_http` dependency — none added.
- Resolved repository-relative Markdown links — no missing targets in the check.
- Screened all repository `.ex`/`.exs` files with a token-aware delimiter check;
  no unmatched `()`, `[]`, or `{}` were reported.
- Screened Elixir source for the common single-backslash default-argument typo;
  no findings.
- Screened changed source/docs/data for `TODO`, `TBD`, and `FIXME` placeholders;
  no findings.

These are source-quality checks, **not an Elixir parser/compiler substitute**.

## TDD status

Tests for the new 0.3 behavior were written as part of the change set before the
corresponding implementation work was considered complete. A static baseline
RED check confirmed the new public API markers did not exist in the reconstructed
0.2.0 baseline. Because ExUnit cannot execute without Elixir/Mix, an executable
RED/GREEN cycle was not available in this container and is not claimed.

New/focused test groups cover Prepared ordering/composition/fingerprints,
response-contract compatibility/failures, Unicode request-byte boundaries and
no-egress behavior, retry inheritance/disable behavior, exact cancellation-token
forwarding, cancellation error preservation, Pristine capability delegation,
batch cancellation scheduling/worker cleanup, exact model lookup/latest ordering,
and privacy-safe metadata.

## BEAM/runtime gates not run here

Run these in the real repository environment and record exact output before
release:

```bash
mix deps.get
mix typesafe.prereq
mix format --check-formatted
mix compile --warnings-as-errors
mix test
mix credo --strict
mix dialyzer
mix docs --warnings-as-errors
mix typesafe.schema.verify
mix typesafe.verify --project-root .
mix hex.build --unpack
mix ci
```

Also run the repository's normal compatibility matrix and, with explicit
credentials, the live/integration fixture gate required by release policy:

```bash
mix test --include live --warnings-as-errors
bash examples/run_all.sh
mix typesafe.record --output tmp/live --baseline test/fixtures/live
```

## Highest-risk runtime checks

1. Compile the new `Prepared`, `ResponseContract`, `RequestBudget`, model-helper,
   metadata, and cancellation paths with warnings as errors.
2. Verify the golden Prepared fingerprint vector and `Jason.Fragment` request
   serialization under the installed Jason/Elixir versions.
3. Confirm Pristine 0.4.0 accepts the exact retry/cancellation request options
   projected by TypeSafe and that `%Pristine.Error{type: :cancelled}` remains the
   underlying cause.
4. Run the synchronized batch cancellation test and confirm no worker/lifecycle
   process remains after cancellation or early stream halt.
5. Run codegen/schema freshness without regenerating first; investigate drift
   rather than overwriting it.
6. Build/unpack the Hex package and inspect files/dependencies from a clean
   consumer using Pristine 0.4.0.

See [HANDOFF.md](HANDOFF.md) for the implementation/file inventory and target-host
closure procedure.
