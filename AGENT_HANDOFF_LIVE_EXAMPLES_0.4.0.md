# TypeSafeSDK 0.4.0 live examples / endpoint-selection handoff

Date: **2026-09-17**
Release target: **0.4.0** (same unreleased release; do not create 0.4.1)
Prior finalized baseline commit: `89086c33a6c94623289aafabd18a5cb8ede8c5e3`

## What this follow-on implements

This change set completes the requested live-example and alternate-endpoint work on
top of the already-finalized 0.4.0 codebase. It deliberately does **not** rewrite
the generated OpenAPI surface or the 0.4 OTP/cancellation runtime.

Implemented areas:

- all live examples use the real TypeSafeSDK -> generated operation -> Pristine
  HTTP path; no fixture/offline fallback was added;
- `examples/support/live.exs` centralizes live credential/endpoint/model selection,
  forces the real Pristine Finch adapter, disables retries by default, and emits
  only a safe configuration summary;
- live executable precedence is explicit option / CLI option > matching environment
  value > application/client default;
- endpoint/model environment names remain `TYPESAFE_BASE_URL` and
  `TYPESAFE_DEFAULT_MODEL`; no competing configuration concept was introduced;
- `TypeSafeSDK.Client` validates nonblank HTTP(S) base roots, rejects URL
  credentials/query/fragment, removes trailing slashes, and retains deployment
  path prefixes for generated operations;
- the evaluation CLI and `mix typesafe.record` accept `--base-url` / `--model`;
- scheduled live capture can use optional repository variables
  `TYPESAFE_BASE_URL` / `TYPESAFE_DEFAULT_MODEL` with the existing credential;
- comprehensive live coverage was added for 0.3 composition/contracts/model
  helpers/budgets/runtime controls/cancellation and the 0.4 OTP facade;
- per-answer telemetry live coverage now exercises Noul, Choice and Score in
  Prepared order with privacy checks;
- recursive live coverage now runs hierarchical descent, bisection, verify/repair,
  coarse-to-fine, and a bounded clarification loop using actual model responses;
- `examples/README.md` now contains the 0.2 -> 0.4 live/deterministic coverage
  matrix and request-count bounds;
- endpoint switching is prominent in README, getting started, client config,
  evaluation docs and cheatsheet;
- the existing 0.4.0 changelog/implementation/handoff/verification docs are updated
  without creating a new release section;
- `PUBLISHING.md` now follows the maintainer's plain/lightweight-tag convention.

No provider-specific Cloudflare URL, model ID or auth claim was invented. A third
party host must actually implement the TypeSafe `/v1/models` + `/v1/systemone`
contract and expected bearer authentication. Only use a credential issued for the
selected host.

## New focused live scripts

- `examples/live_composition_contracts.exs`
- `examples/live_runtime_controls.exs`
- `examples/live_otp_server.exs`

Substantially expanded:

- `examples/live_observability.exs`
- `examples/live_recursive_decisions.exs`

The complete `examples/run_all.sh` path has a documented **63-request upper bound**
with retries disabled. `TYPESAFE_EXAMPLE_RETRY=1` adds one extra operation with
`max_retries: 1`, for at most **65 HTTP attempts** overall. Conditional branches
can use fewer calls.

## Static checks completed in the non-BEAM environment

The implementation environment did not contain `elixir`, `mix`, or `erl`. It also
did not contain `shellcheck`. Do not reinterpret the checks below as BEAM/runtime
verification.

Passed here:

- `bash -n examples/run_all.sh`;
- `.github/workflows/live.yml` YAML parse;
- changed-tree whitespace diagnostics (`git diff --no-index --check` emitted no
  whitespace errors; no-index status only reflected that the trees differ);
- generated runtime modules unchanged (`lib/typesafe_sdk/generated/**`);
- generated provider artifacts unchanged (`priv/generated/**`);
- no hardcoded `https://api.typesafe.ai` remains in executable example `.exs`/`.sh`
  files;
- no `TypeSafeSDK.Test`, fixture transport or stub use exists in advertised live
  standalone scripts;
- all nine `examples/live_*.exs` scripts are present exactly once in `run_all.sh`;
- current release docs contain no `git tag -a` / `git tag -s` instruction;
- modified guide identities/headings are preserved;
- local links in changed Markdown/cheatsheet files resolve;
- CHANGELOG remains one `0.4.0` section dated `2026-09-17` with no `0.4.1` section.

No live API call was made. No alternate-provider compatibility was live-verified.

## Known runtime gates that must be resolved, not hand-waved

1. **Formatting / compilation.** Run `mix format` and inspect the formatter diff,
   then warnings-as-errors compile/tests. Static authoring cannot prove Elixir
   syntax, callback specs, warnings or formatting.
2. **Path-prefix joining.** The new regression in
   `test/typesafe_sdk/runtime_test.exs` expects a base root such as
   `https://example.test/accounts/acme/typesafe/` to produce
   `.../accounts/acme/typesafe/v1/models` while preserving protected auth headers.
   If published Pristine 0.4.0 does not join this way, fix the smallest handwritten
   client/integration boundary. Do **not** edit generated operation modules merely
   to force the test green.
3. **Live helper/CLI precedence.** Run the new
   `live_example_configuration_test.exs`. Explicit CLI/helper options must win over
   environment defaults, including when a lower-precedence environment setting is
   unusable. A selected blank/invalid value with no higher-precedence override must
   fail, not contact the default host.
4. **OTP example lifecycle.** Compile and run `live_otp_server.exs`. Confirm
   simultaneous callers correlate by opaque tag rather than completion order,
   recursive `handle_evaluation/3` stays within the two-request budget, caller
   tokens remain caller-owned, and both server and caller-owned `Task.Supervisor`
   stop cleanly.
5. **Cancellation races.** `live_runtime_controls.exs` intentionally accepts either
   a successful completion or typed cancellation when the real request races an
   immediate cancel. Do not add sleeps/fake transports to manufacture a live win.
   Deterministic lifecycle/failure assertions remain in ExUnit.
6. **Request-count documentation.** Preserve the 63 default / 65 retry-opt-in upper
   bounds unless runtime behavior or scripts are changed; if changed, recount and
   update both README locations before commit.

## Target-host finish sequence

Start from the maintainer's real checkout. Inspect `git status`, the commit after
`89086c33a6c94623289aafabd18a5cb8ede8c5e3`, and any local/post-snapshot changes.
Apply/reconcile this overlay without discarding those changes.

Use the maintenance-only bootstrap documented in `.github/actions/setup/action.yml`
and the existing release docs for unpublished `pristine_codegen` /
`pristine_provider_testkit`. Keep published Hex `pristine 0.4.0` as the runtime;
do not substitute sibling/runtime source overrides just to make gates pass.

Run, in this order:

```bash
mix deps.get
mix typesafe.prereq

mix format
# inspect git diff here; retain only legitimate formatter changes
mix format --check-formatted
mix compile --warnings-as-errors

mix test test/typesafe_sdk/client_configuration_test.exs --warnings-as-errors
mix test test/typesafe_sdk/live_example_configuration_test.exs --warnings-as-errors
mix test test/typesafe_sdk/runtime_test.exs --warnings-as-errors
mix test test/typesafe_sdk/runtime_controls_v030_test.exs --warnings-as-errors
mix test test/typesafe_sdk/prepared_v030_test.exs --warnings-as-errors
mix test test/typesafe_sdk/models_v030_test.exs --warnings-as-errors
mix test test/typesafe_sdk/response_contract_v030_test.exs --warnings-as-errors
mix test test/typesafe_sdk/metadata_v030_test.exs --warnings-as-errors
mix test test/typesafe_sdk/semantic_telemetry_test.exs --warnings-as-errors
mix test test/typesafe_sdk/otp_server_v040_test.exs --warnings-as-errors
mix test test/typesafe_sdk/evaluation_example_test.exs --warnings-as-errors
mix test test/typesafe_sdk/release_consistency_test.exs --warnings-as-errors

bash scripts/check_handoff.sh
mix typesafe.schema.verify
mix typesafe.verify --project-root .
mix ci
```

Do not refresh upstream OpenAPI/codegen merely to change freshness evidence. If a
freshness gate fails, diagnose why before regenerating anything.

Then rebuild/inspect the package and follow `PUBLISHING.md` through the **dry-run**
steps only:

```bash
mix hex.build --unpack
# inspect package inventory, then perform the documented unpacked-artifact
# dependency/docs/hex.publish --dry-run sequence. Do not actually publish.
```

## Authorized live QC

Only after offline gates are green and only with an explicit credential belonging
to the selected endpoint:

```bash
mix test --include live --warnings-as-errors
mix run examples/live_composition_contracts.exs
mix run examples/live_runtime_controls.exs
mix run examples/live_observability.exs
mix run examples/live_otp_server.exs
mix run examples/live_recursive_decisions.exs
```

For complete executable coverage (including all standalone examples plus the
20-row development/held-out evaluation workflow):

```bash
bash examples/run_all.sh
```

Do **not** enable `TYPESAFE_EXAMPLE_RETRY=1` unless the bounded retry-configuration
call is intentionally part of the live QC. Never force a retryable upstream error.
Do not use an alternate host unless its exact URL, matching credential and model ID
are supplied/authorized. A default-provider run is not evidence for a third party.

## Finish documentation, commit and push

After all applicable gates are green:

1. Update `VERIFICATION.md` with the exact follow-on BEAM/QC/live/package results.
   Remove/replace the “pending follow-on” language only for checks actually run.
2. Recheck `HANDOFF.md`, `CHANGELOG.md`, request-count tables and package inventory.
3. Confirm `git status` contains only intended 0.4.0 changes and no credentials,
   captures, `_build`, `deps`, unpacked package tree, or `tmp/` outputs.
4. Commit the follow-on change. Suggested message:

   ```text
   feat: complete 0.4 live examples and endpoint selection
   ```

5. Push the ordinary development/release branch and require the normal
   push-triggered GitHub CI for that exact commit to pass.

The user explicitly wants the next agent to finish/QC/**commit and push** this
follow-on. That authorization does **not** authorize Hex publication or release
creation/tagging. Stop before `mix hex.publish` and before creating/pushing
`v0.4.0`; those remain separate release steps after final-commit CI is green.
