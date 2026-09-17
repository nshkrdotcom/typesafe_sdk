# Publish TypeSafeSDK 0.2.0

Native release validation is recorded in [HANDOFF.md](HANDOFF.md) and
[VERIFICATION.md](VERIFICATION.md). Confirm the final commit's CI is green.
The commands below prepare and publish the current checkout; do not reapply the
historical overlay. Publication has not been performed by this handoff.

## 1. Checkout and tooling

```bash
cd ~/p/g/n/typesafe_sdk
git status --short
mix --version
export MIX_WORKSPACE_OPS_BOOTSTRAP=/tmp/typesafe-tools.exs
```

Use `.tool-versions`: Elixir 1.19.5 / OTP 28.3.1. The bootstrap exists on the
release workstation. On another machine or after `/tmp` cleanup, recreate it
using the pinned maintenance-tool setup in README. Only maintenance tools use
source overrides; Pristine remains the ordinary Hex requirement `~> 0.3.0`.
Review and commit intended changes before publishing, then push and require the
three-pair compatibility matrix and quality job to pass for that exact commit.

## 2. Offline tests, fixtures and QC

```bash
bash scripts/check_handoff.sh
```

This runs dependency/prerequisite checks, formatting, warnings-as-errors compile
and offline ExUnit, strict Credo, Dialyzer, warnings-as-errors docs, schema and
codegen freshness, and unpacked package build. Fixture tests exercise Pristine's
actual serialization/retry/decode path. No regeneration hides pre-existing drift.
For a test-only rerun: `mix test --warnings-as-errors`.

## 3. Live acceptance

Set the API key without including it in shell history (skip the prompt if the
correct key is already exported):

```bash
read -rsp "TypeSafe API key: " TYPESAFE_API_KEY
echo
export TYPESAFE_API_KEY
mix test --include live --warnings-as-errors
bash examples/run_all.sh
mix typesafe.record --output tmp/live --baseline test/fixtures/live
```

Calls may incur charges. Every runnable example uses the actual live endpoint
and disables automatic replay. The all-examples runner includes the development
threshold sweep and frozen held-out evaluation. Inspect `tmp/examples/` and
`tmp/live/`; do not commit secrets or unreviewed captures. A failed request or
ineligible policy fails the runner. Synthetic data verifies workflow operation,
not general model quality. Missing advertised transport bounds remain unverified.

## 4. Package and final CI

```bash
mix hex.build --unpack
mix hex.publish --dry-run
gh run list --workflow ci.yml --limit 3
# Use the run ID for the exact commit you intend to publish:
gh run watch <RUN_ID> --exit-status
```

Inspect `typesafe_sdk-0.2.0/`: runtime source, schemas, upstream source, guides,
cheatsheet, examples and assets must be present; local reports, secrets,
dependencies and maintenance codegen tooling must not be present. The package
has been tested from a clean consumer with Hex runtime dependencies and no
workspace bootstrap. Repeat that smoke test if dependencies or runtime code change.

Keep the maintenance bootstrap exported while building/publishing from this
source checkout. `--dry-run` does not upload. Stop on any failed gate.

## 5. Publish and tag

Authenticate as a package owner if needed, then publish package and docs:

```bash
mix hex.user auth
mix hex.publish
```

Inspect the package name, version **0.2.0**, files and dependencies before
confirming. After successful publication, tag the exact released commit:

```bash
git tag -a v0.2.0 -m "TypeSafeSDK 0.2.0"
git push origin v0.2.0
```

Do not overwrite an existing release tag. Verify
[Hex](https://hex.pm/packages/typesafe_sdk/0.2.0) and
[HexDocs](https://hexdocs.pm/typesafe_sdk/0.2.0/). `mix hex.publish` includes docs;
if only the documentation upload failed after a successful package upload,
retry `mix hex.publish docs` rather than replacing the package.

No unrelated runtime package needs republication. Preserve the 2026-09-16
release date, historical changelog entries, Python provenance and dependency
versions. The opt-in live CI schedule stays disabled until explicitly configured;
no example or gate auto-commits captures or publishes the package.
