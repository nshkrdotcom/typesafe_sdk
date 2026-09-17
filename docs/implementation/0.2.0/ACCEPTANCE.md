# Acceptance and release gates

## Required automated tests

Questions: map/pair order including >32 options; atom/string collisions; invalid
IDs; count boundaries; structured JSON; nesting/UTF-8/type failures; Noul keys;
extras cannot override canonical fields; tuple/raising parity; raw future tags.

Responses: original key types; unknown future preservation; missing/unexpected
known IDs; type mismatch; out-of-domain selections; exact probability/legend key
sets; malformed integer keys/collisions; bounds/sums/tolerance; token counts;
raw/error HTTP metadata; deterministic ties; rounded versus modal Score; explicit
gates and invalid thresholds; available-key diagnostics.

Execution: no HTTP on invalid input; generated transport path; protected semantic
extra_body; metadata nesting; no body/key/error-content leaks in telemetry; one
logical semantic span; real retry sequences; legacy system_one identity remains.

Batch: prepare once; lazy enumeration; bounded concurrent tasks and ordered prefetch/completion windows; ordered and
unordered input identity; per-input timeout/error collection; worker exit cannot
kill caller; raise mode; early stream halt and owner exit terminate workers.

Test facade: actual request/fixture ID/type checking; exact and synthetic
distributions; HTTP/transport/models; retry headers; sequence exhaustion;
request capture; history bound; client isolation and owner cleanup; close/verify.

Schemas: all local refs resolve; output matches the bounded OpenAPI; repeated
export is deterministic; stale output is detected; strict relational rules are
not misrepresented as wire-schema rules.

Example: dataset uniqueness/split separation; multiple acceptable labels;
independent model/policy metrics; correct coverage/error/review denominators;
latency quantiles; failure/token accounting; held-out sweeps rejected.

Release: version/headers/docs consistent at 0.2.0; 2026-09-16 changelog entry;
package includes guides/examples/schema/cheatsheet; README license/artwork intact;
no false live results or accidental dependency/upstream version rewrites.

## Target-host command sequence

Use the repository's existing Pristine workspace/bootstrap mechanism as needed.
Run scripts/check_handoff.sh, which fetches dependencies, checks prerequisites,
format, compile warnings, tests, static analysis, docs, generated/schema freshness
and package. Inspect capability audit separately: unverified runtime guarantees
are not green merely because SDK tests pass.

Run the synthetic live workflow only after explicitly supplying TYPESAFE_API_KEY.
Record actual model/latency/token results rather than borrowing another client's
recordings. Inspect the first capture, then commit it as the approved baseline.
Run evaluation on dev for policy selection; then freeze thresholds for held-out.

## Handoff honesty

Record exact commands, exit states and execution environment. Separate implemented
features, executed static checks, unexecuted ExUnit/Pristine gates, and live/API
checks requiring credentials. Dependency fetch failure or absent Elixir is not a
reason to substitute another language for the production implementation.
