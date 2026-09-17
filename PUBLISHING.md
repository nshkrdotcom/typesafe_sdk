# Publish TypeSafeSDK 0.4.0

Do not publish until `HANDOFF.md` target-host gates are green and the intended
final Pristine source/version has been verified. The `pristine_sdk.xml` supplied
during the static implementation session was identical to the TypeSafeSDK
baseline and cannot establish that dependency contract.

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

```bash
mix hex.publish --dry-run --yes
```

Review package name/version, dependency requirements, files, docs metadata and
licenses. Resolve warnings instead of suppressing them without review.

## Publish and tag

Only after the dry run and all release gates are green:

```bash
mix hex.publish
# verify Hex package/docs, then:
git tag -a v0.4.0 -m "TypeSafeSDK 0.4.0"
git push origin v0.4.0
```

Never overwrite an existing release tag or claim publication before the registry
and documentation are actually visible.
