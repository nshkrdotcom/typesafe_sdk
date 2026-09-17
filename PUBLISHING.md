# Publish TypeSafeSDK 0.3.0

The source delivery and environment limitations are recorded in [HANDOFF.md](HANDOFF.md)
and [VERIFICATION.md](VERIFICATION.md). Do not publish until the real BEAM gates below
pass for the exact commit being released.

## 1. Release train and tooling

Publish in dependency order, from the package directories (not poncho roots):

| Package | Directory | Version | Tag |
| --- | --- | --- | --- |
| Execution Plane HTTP | `../execution_plane/protocols/execution_plane_http` | 0.2.0 | `execution_plane_http-v0.2.0` |
| Pristine runtime | `../pristine/apps/pristine_runtime` | 0.4.0 | `pristine-v0.4.0` |
| TypeSafeSDK | `.` | 0.3.0 | `v0.3.0` |

Execution Plane core remains at published 0.3.0. Pristine Codegen and Testkit
retain their versions; neither needs publishing for this train. The sibling
release handoffs establish the package-prefixed tag convention above.

Use `.tool-versions`: Elixir 1.19.5 / OTP 28.3.1. Before the dependencies are
published, local source QC uses the existing machine-local bootstrap:

```bash
export MIX_WORKSPACE_OPS_BOOTSTRAP="$HOME/.config/mix_workspace_ops/typesafe_local_bootstrap.exs"
bash scripts/check_handoff.sh
mix ci
```

This bootstrap selects sibling sources for QC and ordinary Hex requirements for
packaging. Never commit machine-local paths. After publishing HTTP 0.2.0, resolve
and validate Pristine against that Hex release before publishing Pristine 0.4.0.
Then switch TypeSafe to the maintenance-tools-only bootstrap from
`.github/actions/setup/action.yml`, run `mix deps.get`, and commit the real Hex
lock entries. Do not fabricate checksums for unpublished versions.

The hosted matrix can be run before publication with explicit source commits:

```bash
gh workflow run ci.yml \
  -f pristine_ref=8fd10288abedea3c0820015cdf796dd1dae0dc78 \
  -f execution_plane_ref=63b69ff3984f6f8440866e96a16ceee3ad73bf41
```

Normal push/PR CI and manual runs without these inputs resolve runtime packages
from Hex. Until the dependencies are published, those runs cannot resolve
Pristine 0.4.0; source-matrix evidence is recorded separately in `VERIFICATION.md`.

## 2. Offline tests and release QC

After resolving the published dependencies, run the aggregate gate:

```bash
mix deps.get
mix ci
```

Then run the explicit package/release checks used by the handoff so failures are
visible individually:

```bash
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
```

`mix typesafe.prereq` now verifies the Pristine 0.4 cancellation/runtime
contract in addition to the provider retry-status contract. Do not regenerate
artifacts merely to hide drift; investigate freshness failures first.

The 0.3 suite must specifically prove Prepared composition/fingerprints, strict
response-contract defaults/failures, request-byte no-egress behavior, retry
inheritance, exact cancellation-token forwarding, fail-closed capability
delegation, batch cancellation cleanup/scheduling, pure model helpers, and
privacy-safe response/error metadata.

## 3. Live acceptance

Set credentials without committing them or placing them in shell history:

```bash
read -rsp "TypeSafe API key: " TYPESAFE_API_KEY
echo
export TYPESAFE_API_KEY
mix test --include live --warnings-as-errors
bash examples/run_all.sh
mix typesafe.record --output tmp/live --baseline test/fixtures/live
```

Calls may incur charges. Review outputs before retaining any capture. A live
success cannot by itself prove remote non-execution after cancellation; the
verified Pristine capability establishes local physical cancellation/cleanup,
not rollback of remote side effects.

## 4. Package and final CI

```bash
mix hex.build --unpack
mix hex.publish --dry-run
gh run list --workflow ci.yml --limit 3
# Use the run ID for the exact commit you intend to publish:
gh run watch <RUN_ID> --exit-status
```

Inspect `typesafe_sdk-0.3.0/`: runtime source, schemas, upstream source, guides,
cheatsheet, examples, assets, and implementation records must be present;
secrets, local reports, `_build/`, `deps/`, and maintenance-only checkout code
must not leak into the package. Repeat the clean-consumer package check because
0.3.0 changes the runtime prerequisite to Pristine 0.4.0.

## 5. Publish and tag

After every required gate is green, authenticate and publish:

```bash
mix hex.user auth
mix hex.publish
```

Inspect the package name, version **0.3.0**, files, and dependency requirements
before confirming. After successful publication, tag that exact commit:

```bash
git tag -a v0.3.0 -m "TypeSafeSDK 0.3.0"
git push origin v0.3.0
```

Do not overwrite an existing release tag. Verify the 0.3.0 package and docs on
Hex/HexDocs. If only the documentation upload fails after the package succeeds,
retry `mix hex.publish docs` rather than replacing the package.

Release date: **2026-09-17**. Preserve historical changelog entries, MIT
licensing, acknowledgements, source provenance, and the opt-in live-CI policy.
Publication and tags remain separate maintainer actions. Actual source/package QC
is recorded in `VERIFICATION.md`; Hex-only resolution and the full publish dry
run follow dependency publication.
