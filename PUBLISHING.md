# Publish TypeSafeSDK 0.4.0

Target-host results are recorded in `VERIFICATION.md`. Pristine compatibility
was verified against published Hex 0.4.0. Publication and tagging are pending.
Require the normal push-triggered GitHub CI run for the final release commit to
pass before publishing; do not use runtime source overrides for that release run.

For checkout maintenance commands, load the bootstrap from
`.github/actions/setup/action.yml` with its pinned Pristine maintenance checkout
(`04ba7b112413591f5cb9260f1d270bbbeb8a0630`). The codegen/testkit packages are
not yet published on Hex. Override only those tools; retain Hex runtime resolution.
The bootstrap deliberately disables source overrides for Hex packaging commands.

## Preflight

```bash
mix deps.get
mix typesafe.prereq
mix format --check-formatted
mix compile --warnings-as-errors
mix test --warnings-as-errors
mix reach.check --arch --smells
mix credo --strict
mix dialyzer
mix docs --warnings-as-errors
mix typesafe.schema.verify
mix typesafe.verify --project-root .
mix hex.build --unpack
mix ci
```

Run live tests only under the project's explicit release policy and with a real
credential. Do not substitute fixture results for live evidence.

## Inspect the package

Confirm the unpacked 0.4.0 package contains runtime source, `priv/upstream`,
committed JSON Schemas, guides, examples, README, CHANGELOG, LICENSE and the 0.4
implementation record. Confirm generated OpenAPI operation ownership and the
Pristine runtime dependency remain as intended.

Check that runtime code does not depend on Reach, ExDoc, Credo, Dialyzer,
Pristine Codegen or provider testkit. Those are development/test tooling.

## Dry run

Publish from the unpacked artifact so documentation compilation does not require
checkout-only, unpublished maintenance tools. This also verifies the actual
package layout. From the repository root after `mix hex.build --unpack`:

```bash
cp mix.lock typesafe_sdk-0.4.0/mix.lock
cd typesafe_sdk-0.4.0
unset MIX_WORKSPACE_OPS_BOOTSTRAP
mix deps.get
mix hex.publish --dry-run --yes
```

The copied lockfile pins the QC dependency versions locally; it is not included
in the Hex package. Keep this shell in the unpacked directory for publication.

Review package name/version, dependency requirements, files, docs metadata and
licenses. Resolve warnings instead of suppressing them without review.

## Publish and tag

Only after the dry run and all release gates are green:

```bash
mix hex.publish
# verify Hex package/docs, then return to the repository:
cd ..
git tag -a v0.4.0 -m "TypeSafeSDK 0.4.0"
git push origin v0.4.0
```

Never overwrite an existing release tag or claim publication before the registry
and documentation are actually visible.
