# Publish the minimum TypeSafe release chain

Prepared on 2026-09-16. All three packages have refreshed direct dependency
requirements and lockfiles. Execution Plane core **0.3.0 is already on Hex**;
no core, workspace, Codegen, Testkit, or other lane publication is needed.

| Order | Package | Action |
| --- | --- | --- |
| 1 | `execution_plane_http 0.1.0` | Replace the owner's initial upload with refreshed dependencies |
| 2 | `pristine 0.3.0` | Publish the runtime package |
| 3 | `typesafe_sdk 0.1.0` | Publish the unpacked SDK distribution |

## Commands

Run each block after the preceding upload succeeds. These publish package and
documentation. No portfolio or MWO command is involved.

```bash
unset MIX_WORKSPACE_OPS_BOOTSTRAP MIX_WORKSPACE_OPS_OVERLAY

cd ~/p/g/n/execution_plane/protocols/execution_plane_http
mix deps.get && mix hex.publish --replace
```

```bash
cd ~/p/g/n/pristine/apps/pristine_runtime
mix deps.get && mix hex.publish
```

```bash
cd ~/p/g/n/typesafe_sdk
mix hex.build --unpack
cd typesafe_sdk-0.1.0
mix deps.update --all && mix hex.publish
```

The SDK distribution excludes checkout-only generation/test tooling. Refreshing
its dependencies also replaces any lockfile left by an earlier local build.
Pristine's old HTTP lock entry was removed deliberately: its next `deps.get`
must obtain the replacement release's metadata and checksum, not the first upload.

## Hex version handling

- The HTTP replacement must be accepted within Hex's replacement window. If Hex
  rejects it as too old, stop: HTTP needs a patch release and the downstream
  requirement must be adjusted. Do not publish Pristine against the old upload,
  which requires Execution Plane 0.2.x instead of 0.3.x.
- If the next package still sees old metadata or cannot find the preceding new
  release, wait briefly and retry its dependency command. Do not change sources.
- Pristine 0.3.0 was still unpublished when preparation began. If you published it
  in the meantime, use `mix hex.publish --replace` for it too, within Hex's window.
- If only docs fail after a successful upload, run `mix hex.publish docs` there.
- `mix hex.info execution_plane_http 0.1.0`, `mix hex.info pristine 0.3.0`, and
  `mix hex.info typesafe_sdk 0.1.0` inspect the exact releases.

## Verification and remaining advisory

HTTP's package CI, Pristine's 315 runtime tests and static/docs/package checks,
and the SDK's offline/live tests, generated verification, static analysis, docs,
and package build are checked against the updated dependencies. Core resolves
from Hex 0.3.0; pending HTTP/Pristine replacements use the local source hook.
Final downstream Hex resolution happens after each preceding upload.

Pristine's development/test dependency `plug_cowboy` resolves Cowboy 2.19.0 and
Cowlib 2.20.0, their latest stable versions. Hex still reports EEF-CVE-2026-43966
and EEF-CVE-2026-43969 against Cowlib 2.20.0. There is no newer Cowlib release;
these warnings are not suppressed. Cowboy/Cowlib are not published Pristine
runtime dependencies. Bandit is updated to 1.12.5 and Mint resolves to 1.10.0.

Source, lockfile, and release documentation changes are committed and pushed.
No package was published by the agent.
