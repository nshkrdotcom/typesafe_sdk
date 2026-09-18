# Publish TypeSafeSDK 0.4.0

The 0.4.0 implementation/live release candidate completed target-host offline,
package and real-API QC, and the pushed implementation commit
`a1b77fa0aca1eb53f310af4a1c282764b2283ef9` passed the normal push-triggered
GitHub `CI` workflow in run `35293833582` across Elixir/OTP 1.18/27, 1.19/28 and
1.20/29 plus the quality job. `VERIFICATION.md` records the executed evidence.
Hex publication and the `v0.4.0` tag are still separate, explicit maintainer acts.

Any commit made after that evidence must itself pass the applicable final gates.
A documentation/release-procedure-only change does **not** require repeating
billable live calls when no runtime/example behavior changed, but it does require
non-live QC, a rebuilt package/docs dry run when packaged files changed, and the
normal push-triggered CI for the exact final commit.

For checkout maintenance commands, use the bootstrap defined by
`.github/actions/setup/action.yml`, whose maintenance checkout is currently pinned
to Pristine `04ba7b112413591f5cb9260f1d270bbbeb8a0630`. The unpublished
`pristine_codegen` and `pristine_provider_testkit` packages are checkout tooling;
keep published Hex Pristine as the runtime unless intentionally testing an
explicit prerelease source ref. Hex package dry-runs unset the workspace bootstrap.

## Release-QC driver

`scripts/release_qc.sh` encodes the release sequence without publishing, tagging,
committing or pushing anything:

```bash
bash scripts/release_qc.sh offline
bash scripts/release_qc.sh package-dry-run
TYPESAFE_RELEASE_LIVE=1 bash scripts/release_qc.sh live
# commit + push intentionally, then:
bash scripts/release_qc.sh github-ci
```

The `live` command is deliberately opt-in and billable. With retries disabled it
has a 67-request upper bound: the documented 63-request complete example/evaluation
path, two live ExUnit requests, and the recorder's two real operations. Each
successful live step writes a `.done` marker and log under ignored
`tmp/release-qc/0.4.0/live/`. If a late step fails, fix the defect and rerun the
same command; already-passed steps are skipped. Use
`bash scripts/release_qc.sh live-reset` only when intentionally repeating every
billable live step. If a fix changes shared runtime behavior that could invalidate
an earlier live result, reset or remove the affected markers and rerun the
appropriate evidence rather than treating stale markers as proof.

The driver never refreshes/regenerates upstream artifacts implicitly. Refresh and
generation remain intentional maintenance operations whose diffs must be reviewed.

## Offline preflight

The expanded non-live gate is `scripts/check_handoff.sh` followed by `mix ci`; the
release driver runs both:

```bash
bash scripts/release_qc.sh offline
```

This covers dependency resolution, `mix typesafe.prereq`, format, warnings-as-errors
compile/tests, strict Credo, Reach architecture/smells, Dialyzer, warnings-as-errors
ExDoc, schema/codegen freshness, Hex package build, and the aggregate `mix ci`.
Reach smell findings are advisory when the architecture command exits zero; do not
weaken an architecture rule merely to hide a finding.

Do not refresh the upstream OpenAPI or regenerate committed code merely to make a
freshness check green. Diagnose drift first.

## Inspect and dry-run the actual package

Run:

```bash
bash scripts/release_qc.sh package-dry-run
```

The command rebuilds `typesafe_sdk-0.4.0`, copies the checkout lockfile only for
local QC dependency pinning, unsets `MIX_WORKSPACE_OPS_BOOTSTRAP` and
`GITHUB_WORKSPACE` inside the unpacked artifact, resolves published dependencies,
and runs:

```bash
mix hex.publish --dry-run --yes
```

Nothing is published. Review the dry-run inventory and confirm the artifact
contains runtime source, `priv/upstream`, committed JSON Schemas, guides, examples,
README, CHANGELOG, LICENSE and the 0.4 implementation record. Runtime requirements
should remain Pristine, Jason and Telemetry; Reach, ExDoc, Credo, Dialyzer,
Pristine Codegen and provider testkit are development/test tooling.

If any packaged file changes after a successful dry run, rebuild and dry-run the
package again so the evidence applies to the exact artifact intended for release.

## Live release evidence

Only after offline/package gates are green, and only with a credential belonging
to the selected endpoint, run:

```bash
export TYPESAFE_API_KEY='credential-issued-for-this-endpoint'
# Optional only when intentionally validating a matching alternate deployment:
# export TYPESAFE_BASE_URL='https://provider.example/deployment-root'
# export TYPESAFE_DEFAULT_MODEL='provider-model-id'

TYPESAFE_RELEASE_LIVE=1 bash scripts/release_qc.sh live
```

The live driver disables `TYPESAFE_EXAMPLE_RETRY`, runs live-inclusive ExUnit and
the recorder once, then executes each standalone example and the development/
held-out evaluation workflow as separately checkpointed steps. This is preferable
to blindly restarting `examples/run_all.sh` after a late failure because successful
billable calls are not repeated merely to regain progress.

Never send the TypeSafe credential to a guessed alternate host. Alternate-provider
compatibility requires an exact authorized URL, matching credential/model and the
TypeSafe `/v1/models` + `/v1/systemone` contract.

## Final commit and GitHub CI

After all applicable gates are green, update `VERIFICATION.md`/`HANDOFF.md` with
what actually ran, inspect `git diff --check` and `git status`, and ensure no
credentials, captures, `tmp/`, `_build`, `deps` or unpacked package tree are staged.
Commit and push intentionally. Then require push-triggered CI for that exact SHA:

```bash
bash scripts/release_qc.sh github-ci
```

The command is read-only with respect to git/GitHub state: it does not create an
empty commit or push anything. It waits briefly for the `ci.yml` push run, verifies
the run belongs to current `HEAD` and event `push`, watches it, and requires a
`success` conclusion. If no run exists, diagnose the workflow/push rather than
manufacturing release evidence.

## Publish and tag

Only after the exact final commit has green release evidence and push-triggered CI:

```bash
mix hex.publish
# Verify the package and HexDocs are actually visible, then return to the repo.
cd ..
# Maintainer convention: plain/lightweight release tags (not -a / -s).
git tag v0.4.0
git push origin v0.4.0
```

Never overwrite an existing release tag or claim publication before the registry
and documentation are actually visible.
