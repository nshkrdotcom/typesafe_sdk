# Publish TypeSafeSDK 0.2.0

Native release validation is recorded in [HANDOFF.md](HANDOFF.md) and
[VERIFICATION.md](VERIFICATION.md), with linked CI runs. The local handoff,
live tests, evaluation workflow, package build and clean consumer smoke passed.
Confirm the final commit's CI is green before publishing. No Hex publication
has been performed by this handoff.

## Before publishing

1. Apply the overlay at the exact baseline repository root and inspect the diff.
2. Configure the existing pinned Pristine maintenance-tool bootstrap (see README).
   Keep the runtime Hex requirement ~> 0.3.0; do not republish unrelated runtimes.
3. Run `bash scripts/check_handoff.sh` and the full configured compatibility matrix.
   Resolve failures in code/tests/docs; do not disable checks to obtain green status.
4. With a real API key, run the existing live tests and `mix typesafe.record`.
   Review wire ordering, relational contracts, actual model metadata and fixture
   diffs. Unadvertised transport capabilities remain unverified unless separately
   implemented and contract-tested in their owning runtime.
5. Run the labeled development/held-out example as workflow acceptance, not as a
   performance claim. Inspect package contents for schemas, guides, cheatsheet and
   examples, and verify no local API keys or reports are included.

```bash
mix hex.build --unpack
# Inspect typesafe_sdk-0.2.0/ and test installation from that unpacked package
# in a clean host project without workspace path overrides.
mix hex.publish
```

Publication is an explicit maintainer action. Verify the uploaded package and
HexDocs show 0.2.0 and that runtime headers report the same version. Keep historical
CHANGELOG entries, Python 0.6.0 provenance and Pristine/tooling dependency versions
unchanged; they are not SDK version placeholders.

The release includes no fabricated live fixture baseline. Approve real recordings
through code review. The live schedule remains disabled until explicitly enabled
with TYPESAFE_LIVE_ENABLED=true and TYPESAFE_API_KEY in repository configuration.
