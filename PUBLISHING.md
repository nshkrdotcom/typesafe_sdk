# Publish TypeSafeSDK 0.3.0

The source delivery and environment limitations are recorded in [HANDOFF.md](HANDOFF.md)
and [VERIFICATION.md](VERIFICATION.md). Do not publish until the real BEAM gates below
pass for the exact commit being released.

## 1. Checkout and tooling

```bash
cd ~/p/g/n/typesafe_sdk
git status --short
mix --version
export MIX_WORKSPACE_OPS_BOOTSTRAP=/tmp/typesafe-tools.exs
```

Use `.tool-versions`: Elixir 1.19.5 / OTP 28.3.1. Recreate the documented
maintenance-tool bootstrap when required by the source checkout. Runtime Pristine
must resolve to `~> 0.4.0`; do not downgrade to the 0.3 runtime line. The
TypeSafe package remains responsible for semantic behavior while Pristine owns
HTTP execution, retry, and physical unary cancellation.

## 2. Offline tests and release QC

Start with the repository's aggregate gate:

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
Publication is always a separate maintainer action; this implementation overlay
does not claim that 0.3.0 has been published or BEAM-verified.
