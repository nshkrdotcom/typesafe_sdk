# TypeSafeSDK 0.2.0 verification record

Release date: **2026-09-16**. Baseline: **typesafe_sdk(2).xml**, reconstructed as
97 files. These results describe the delivered source and archives, not a
published release or a successful BEAM build.

## Completed delivery checks

| Check | Observed result |
| --- | --- |
| Source inventory | 165 working files; 68 added and 28 modified relative to the packed baseline |
| Overlay inventory | 96 root-relative files, all added or changed; no unchanged files or required deletions |
| Planning archive | 6 Markdown documents; byte-identical to their copies under docs/implementation/0.2.0 |
| Archive integrity | Both ZIP CRC checks passed; no duplicate, absolute or parent-traversal paths; no symbolic links |
| Overlay reconstruction | Applying the ZIP to all 97 baseline files reproduced all 165 working files byte-for-byte; zero differences |
| Executable metadata | Shell script stored with executable 0755 ZIP permissions |
| Shell syntax | bash -n scripts/check_handoff.sh completed successfully; the commands inside were not executed |
| Elixir source screen | 105 .ex/.exs files screened for lexical tokens and balanced blocks/delimiters; no reported findings |
| Serialized files | 9 JSON and 3 YAML files parsed successfully |
| JSON Schema exports | All 3 exports passed Python Draft 2020-12 schema checks and exact semantic derivation from committed OpenAPI |
| Local schema references | 39 $ref/$dynamicRef occurrences resolved in the exported schemas |
| Synthetic evaluation data | 12 development and 8 held-out rows; unique IDs, valid split labels and answer domains |
| Documentation | 65 relative Markdown targets and 26 registered documentation paths resolved |
| Release consistency | Mix version, public version and schema release markers are 0.2.0; CHANGELOG.md includes 2026-09-16 |
| Preserved source | Existing generated code, codegen source, upstream OpenAPI, IR and inventories are byte-unchanged |
| Preserved presentation/license | LICENSE, SDK artwork and the exact README license ending are unchanged |

The source screen is **not an Elixir parser or compiler**. JSON Schema validation
was performed with Python, not by executing the supplied Mix export/verify tasks.
Relative-link checks do not render HexDocs or establish external-link liveness.
Archive reconstruction is a byte comparison against this reconstructed baseline;
unpacked files outside the supplied Repomix input were not available to compare.

## Test implementation inventory, not execution results

The overlay adds **10 ExUnit test files containing 63 test declarations**,
plus doctest coverage. The working tree contains 20 test files with
97 test declarations in total. Declarations include parameterized tests;
these counts are not an executed test count or a passing-test claim.

The new suites cover question/JSON validation, ordered request serialization,
caller-key restoration, response/request consistency, uncertainty helpers, the
real Pristine execution seam, retry/error sequences, supervised batch lifecycle
and prefetch bounds, fixture contracts, telemetry privacy, schema freshness,
capability requirements, evaluation metrics/policy discipline and release docs.

## Not executable in the delivery environment

The environment had no **elixir, erl or mix**, and dependency access was
unavailable. The following results are explicitly **NOT RUN**:

- Elixir compilation, mix format and ExUnit, including doctests and transport tests.
- Credo, Dialyzer, ExDoc and the Elixir/OTP compatibility matrix.
- Mix schema tasks, Pristine generated-artifact verification and Hex package build.
- Real TypeSafe API calls, recordings and labeled model/policy evaluation.

No source-reviewed test is presented as a completed red/green TDD cycle. No live
response, performance number, accuracy result or initial recording was invented.
The existing historical changelog is preserved as history, not evidence that the
new 0.2.0 implementation passed its release gates.

## Operational boundaries

The SDK implements bounded batch execution and ordered prefetch windows. It does
not claim to supply a global HTTP queue, streaming response-byte limits or
physical transport cancellation. Those belong to Pristine/the transport and are
reported as unverified unless advertised. Advertised capabilities still require
runtime enforcement tests; the parser's unit tests cannot establish them.

Apply the overlay at the repository root, then follow HANDOFF.md and
scripts/check_handoff.sh. Record exact target-host commands, tool versions,
results and corrections before treating this as a verified release. No commit,
push, live execution or publication was performed for this delivery.
