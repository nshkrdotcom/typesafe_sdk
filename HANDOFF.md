# TypeSafeSDK 0.2.0 implementation handoff

## Native QC status

The overlay has now been compiled and exercised on Elixir 1.19.5 / OTP 28.3.1.
The complete non-regenerating handoff script passes, including strict Credo,
Dialyzer, warning-free compilation/ExDoc, schema/codegen verification and Hex build.
Live tests pass: **1 doctest, 98 tests, zero failures**. Real recording and the
12-record development / eight-record held-out evaluation workflow also passed.
See [VERIFICATION.md](VERIFICATION.md) for corrections and execution details.

Compatibility CI is pending the release-fix push. Publication has not occurred.
The earlier delivery-environment limitations below describe the original overlay,
not the native QC performed in this checkout.

Release date: **2026-09-16**. Base: the **97 packed files in typesafe_sdk(2).xml**.
Apply the overlay at that repository's root. It contains only new/modified paths;
there are no deletions, vendored dependencies, BEAM binaries or fake live captures.
The source version is 0.2.0; this handoff does **not** claim it is published to Hex.

Read [the specification](docs/implementation/0.2.0/SPECIFICATION.md),
[implementation status](docs/implementation/0.2.0/IMPLEMENTATION_STATUS.md), and
[verification record](VERIFICATION.md). The standalone planning ZIP contains the
same six planning documents that are retained under docs/implementation/0.2.0.

## What is implemented

Strict tuple/bang question constructors, top-level conveniences, JSON validation,
ordered Choice encoding, finite caller-key restoration, cached Prepared sets,
relational response validation, raw fidelity, enriched existing answer structs,
uncertainty and response helpers, semantic evaluate/evaluate!, supervised indexed
batch streams, consumer fixtures at the real Pristine transport seam, safe
semantic telemetry, retry queries, runtime-capability auditing, schema export,
labeled decision evaluation and release/documentation/CI changes are built.

The legacy constructors still return their original structs. `system_one` stays
wire-oriented and string-keyed; `evaluate` adds strict semantics. Both use the
same generated Pristine operations. The generated clients/schemas, bounded
OpenAPI, provider IR and generation inventories are unchanged. See the migration
guide for intentionally stronger probability/usage validation in known responses.

## What was actually verified here

This environment does not contain `elixir`, `erl`, or `mix`. Dependency access
was unavailable. No compiler, ExUnit, formatter, Credo, Dialyzer, ExDoc, Pristine
verification, Hex build or live API gate was run. There is no asserted green
runtime result and no measured model accuracy/latency/calibration. Tests are
implemented but not executed; source review is not an executed TDD cycle.

The completed static delivery checks are recorded in VERIFICATION.md. They
include schema validation/reference resolution, exact schema-source derivation,
serialized configuration/data parsing, source lexical/delimiter screening,
version/link/asset checks and overlay reconstruction. Lexical screening is not
an Elixir parser and cannot establish that the code compiles.

## Target-host completion instructions

Finish this implementation in the real BEAM environment: execute the tests,
fix defects in production code/tests/docs, repeat until the required gates are
green, and record exact results. Do not replace Pristine with a second runtime,
disable assertions, or present fixture-only behavior as production support.

Use the existing contributor setup in [README](README.md) for the pinned
Pristine codegen/provider-testkit workspace bootstrap. Runtime Pristine remains
`~> 0.3.0`; do not downgrade it. The composite CI setup preserves the baseline's
pinned maintenance-tools revision. Keep dependency versions separate from the
SDK version. No mix.lock was present in the supplied packed baseline; resolve
and review dependencies according to repository release policy, not an invented
lock file from an environment that could not fetch them.

From the applied repository root:

```bash
mix deps.get
mix typesafe.prereq
# Formatting was not executable in the delivery environment.
mix format
# Inspect the formatter diff; do not conceal generated-artifact drift.
git diff --stat
bash scripts/check_handoff.sh
```

The script checks formatting, warnings-as-errors compilation, ExUnit, strict
Credo, Dialyzer, ExDoc, schema freshness, generated artifact freshness and the Hex
package. It deliberately does not refresh upstream data or regenerate artifacts
before checking them, and does not publish, commit or make live calls. Fix each
failure and rerun. Run the configured compatibility matrix as well; those pairs
are test targets, not locally established support evidence.

### Highest-value runtime integration checks

* Verify the cached Jason.Fragment and ordered Choice data pass through the real
  Pristine serializer unchanged, including >32 options. The integration tests
  inspect the actual HTTP request bytes rather than an alternate serializer.
* Confirm 529/599/200 sequences, provider retry headers, timeout overrides, error
  metadata and retry counts against the installed Pristine 0.3 runtime. Test
  response fixtures, malformed known answers and raw unknown future answers.
* Exercise the synchronized batch tests: bounded workers, ordered/unordered input
  association, ordered prefetch/window bounds, timeout, worker exit, early halt, trapping callers and caller
  death. Check for lingering lifecycle/supervisor/task processes. Do not add
  sleeps in place of the synchronization contracts or weaken cleanup assertions.
* Attach telemetry handlers and check automatic metadata excludes state,
  questions, headers, keys, raw errors and exception reasons/stacktraces. Explicit
  caller metadata is opt-in content. Abrupt kill cannot guarantee a stop event.
* Run the labeled example's loader/metrics/policy tests, schema task round trips,
  doctests and release-consistency tests. Inspect the installed package contents
  and use it from a host project without workspace overrides.

### Runtime bounds are not assumed

```bash
mix typesafe.capabilities
```

Unadvertised global outstanding-request bounds, queue bounds, streaming response
byte limits, deterministic overload and physical cancellation cleanup report
`unverified`. `runtime_requirements` fails closed if an adapter does not advertise
a requested capability. Advertising is not independent proof: verify enforcement
in the actual owning Pristine transport. The SDK's bounded batch tasks are not a
global HTTP queue or streaming response limit. Do not mark these capabilities
green based on unit tests of the advertisement parser.

## Real API acceptance (requires explicit credentials)

Set TYPESAFE_API_KEY in the invoking environment; never commit it. API evaluation
may incur charges. Existing retry defaults are retained and can replay ambiguous
submissions; the record task explicitly disables retries.

```bash
# Inspect the existing live tests and account/model configuration first.
mix test --include live
mix typesafe.record --output tmp/live --baseline test/fixtures/live

mix run examples/evaluation/run.exs -- \
  --split development --sweep --max-auto-error 0.05 \
  --output tmp/development.json
mix run examples/evaluation/run.exs -- \
  --split held-out --policy tmp/development.policy.json \
  --output tmp/held-out.json
```

The live tag is excluded by default; `--include live` enables it explicitly.
The capture task makes two real operations
(models and mixed evaluation), retains actual responses/metadata, and writes
review diffs without changing approved baselines. There is intentionally no
invented initial baseline. Review and explicitly approve first captures.

The evaluation data is synthetic illustrative data, not calibration evidence.
Development threshold sweeps reuse predictions. Held-out runs require a frozen
policy/model and reject threshold overrides. No eligible development policy is
reported without fallback thresholds; incomplete runs do not freeze a policy.
Reports retain observations on policy-selection failure and flag model mismatch.

The scheduled workflow stays disabled until the repository variable
TYPESAFE_LIVE_ENABLED is true and TYPESAFE_API_KEY is configured. No pull-request
trigger or automatic fixture commit is added.

## Release closure

Update this handoff/verification record with actual commands, versions, pass/fail
counts and remaining limitations. Follow [PUBLISHING.md](PUBLISHING.md) only after
the intended release gates pass. Preserve the original MIT license, README
license ending, artwork, historical changelog and upstream/tooling provenance.
Commit the finished changes after successful QC; publication remains a separate,
explicit maintainer action.

Suggested commit subject:

```text
feat: release TypeSafeSDK 0.2.0 semantic evaluation and decision tooling
```
