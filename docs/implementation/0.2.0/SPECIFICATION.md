# Specification: complete 0.2.0 scope

## 1. Architecture and compatibility

Keep TypeSafeSDK.Generated.* and the existing Pristine execution/retry/auth
pipeline. Keep the legacy Noul.new(attrs), Choice.new(criteria, opts),
Score.new(criteria, opts), system_one/4 and list_models/2 interfaces. system_one
continues to return string-keyed wire-oriented answers and permits top-level
extra_body overrides. Do not silently change their constructor return types.

Add strict constructors under TypeSafeSDK.Question.Noul/Choice/Score, each with
new (tuple) and new! (raising) forms, and ergonomic raising top-level noul,
choice and score helpers. Add evaluate/evaluate!, prepare/prepare!,
evaluate_many and evaluate_stream. Strict evaluate rejects extra_body overrides
of state/model/questions so its validation cannot be bypassed.

Use ONE public SystemOneResponse and the existing public answer structs,
additively enriched. TypeSafeSDK.Response and TypeSafeSDK.Answer.* are helper
namespaces, not duplicate response/answer structs. Preserve raw JSON, raw HTTP
response, request ID, model, usage, retries and elapsed time.

## 2. Questions and JSON

* Strict questions support optional JSON descriptions/instructions; strings must
  be nonblank where a description is present; objects/lists remain structured.
* Choice: 2..255 distinct options. Lists of pairs preserve order; maps sort by
  wire key. Atom/string keys restore via a finite registry, never by creating
  atoms from response strings. Reject duplicate normalized keys (including
  :billing versus "billing") before converting to maps.
* Score: 2..10 ordered levels. Strings, structured descriptions and
  {label, description} pairs; pairs encode as label/description JSON objects.
* Noul: optional true/false descriptions only. Both boolean atoms and wire
  strings are accepted; collisions are rejected.
* Question extras preserve unknown fields but cannot replace type, instructions
  or criteria. Raw unknown question types remain usable through prepare and
  evaluate, retaining extra JSON fields.
* JSON normalization rejects functions, PIDs, arbitrary structs, invalid UTF-8,
  non-JSON atom values and normalized object-key collisions. Nesting is bounded.
  Caller state is validated before execution. Empty IDs are invalid.
* Validation errors use Error.type == :invalid_request, field_path plus a
  component-list path and structured details. Existing error classifications
  remain available. No raw state/body in automatic telemetry.

## 3. Response semantics and relational validation

Strict evaluation joins each known answer to its submitted question. Validate:
matching known answer IDs/types; selected Choice membership; exact distribution
key domain; numeric probabilities/confidence in [0,1]; probability sum within a
configurable tolerance (default 0.02); Score range and exact integer legend/
probability domains; nonnegative integer usage values when present. A known
question must have an answer entry. An unknown future answer tag is retained in
raw/unknown_answers and skipped, including when it replaces a known answer.
Unexpected KNOWN answers are errors; unexpected UNKNOWN tags remain forward
compatible. Malformed known answers fail, never disappear silently.

Restore only caller-supplied keys. Add answer id/raw, Choice option order, Score
level/label/description/ordered levels and original rubric, while preserving
server legend. Score rounded expectation is not a modal prediction. No assertion
that provider confidence is a calibrated correctness probability.

Provide fetch/fetch! (missing-key errors list available IDs), nouls/choices/scores,
Noul yes?/2 and confidence, Choice ranked/margin, Score ranked/expected_level/
max_level/normalized, generic confidence and gate. Gate requires EXPLICIT act
and review thresholds, validates review <= act, and makes no safety guarantee.

## 4. Repeated and concurrent evaluation

Prepared holds validated/encoded questions and finite identity metadata once.
Every evaluation still enters Generated.SystemOne.create -> Client -> Pristine.
Lazy evaluate_stream bounds in-flight work; evaluate_many collects that stream.
Use unlinked supervised tasks, kill timed-out work, clean up on early halt,
exception and caller termination. No process-global registry or application
supervisor is required. Ordered streams use finite `max_pending` windows (default
four times concurrency; at least concurrency, at most 10000) so a slow predecessor
cannot allow unbounded completed-result buffering or source prefetch. One window
finishes before the next begins; this explicit utilization tradeoff avoids
reimplementing OTP task monitoring/timeouts. Unordered streams use direct OTP
demand-driven execution. Escaping worker exceptions are sanitized before OTP
Task crash reporting can print input-bearing arguments. One result per input; unordered results retain a
zero-based batch_index on responses and errors. on_error is :collect or :raise.
Shared invalid schemas/options fail before spawning work. HTTP timeout retains
existing seconds/timeout_ms semantics; task_timeout_ms and attempt_timeout_ms are
explicitly milliseconds. Batch bounds do NOT claim global HTTP queue bounds.

## 5. Consumer testing facade

TypeSafeSDK.Test creates an explicit test client using Pristine.Ports.Transport.
Production serialization, retry/classification and decoding remain in use.
Provide answer stubs, exact distributions, synthesized distributions, HTTP and
transport errors, model lists, finite retry sequences, model/usage/request-ID
metadata, recorded requests and verify!/close. Validate stub IDs/types and
option/level domains against ACTUAL serialized questions. Fail loudly on mismatch
or exhausted sequences. Fixture state is isolated per client, monitored to its
owner and shared explicitly by concurrent child tasks; captured history bounded.
Never call the live service from the test facade.

## 6. Observability and runtime capabilities

A semantic evaluation span covers validation through decoded result, including
Pristine attempts. Emit safe operation/model/count/status/request-ID/retry/token
metadata, durations and classifications. Caller metadata is nested, cannot
replace reserved fields, and should contain IDs, not content. Do not emit bodies,
state, questions, authorization, exception reasons or raw Error structs.
Generic attempt telemetry/retries remain Pristine-owned.

Expose Error.retryable?/1 and policy-aware retryable?/2, retry_after/1. Document
at-least-once execution and possible repeated upstream processing/billing after
ambiguous transport failures. Do not change retry defaults.

Ship a runtime-capability audit/report and fail-closed requirements check. The
supplied SDK establishes no runtime API for global bounded queues, streaming
response-byte caps or physical request cancellation. Mark these unverified,
not implemented/guaranteed. A Pristine transport may explicitly advertise the
capabilities through the documented SDK adapter callback. Requirements that are
not advertised must fail. No second pool, queue, HTTP stack or retry engine is
added. Target-environment verification must establish actual enforcement.

## 7. Schemas, evaluation workflow, docs and release

Export self-contained System One request/response and models JSON Schemas from
priv/upstream/openapi.json (rewrite internal refs into $defs). Deterministic
export and semantic freshness verification tasks; no Zoi or second handwritten
wire-schema authority. The stricter relational layer is documented separately.

Ship runnable support-triage evaluation example with synthetic development and
held-out JSONL datasets, multiple acceptable labels, separate model and policy
metrics, auto-routing coverage/error, review metrics, failures, p50/p95 latency,
token usage, request IDs/model versions and probability records. Threshold sweeps
use development data only; held-out evaluation freezes thresholds. No invented
accuracy, calibration or latency results.

Provide decision-pattern guides (confidence routing, composite scoring,
speculative fan-out/cancellation), testing/batching/telemetry/schema/migration
references, cheatsheet and executable examples. Register extras/package assets.
Preserve README badge/artwork/architecture narrative and exact license ending.
Update current version references to 0.2.0; preserve historical changelog entries
and dependency/upstream version numbers. CHANGELOG entry date is 2026-09-17.
Compatibility-matrix CI and opt-in scheduled live fixture capture/diffs are
included. No secrets, fake recordings or auto-committing changed live outputs.
