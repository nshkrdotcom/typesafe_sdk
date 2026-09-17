# Answers, Distributions and Explicit Policy

`SystemOneResponse` is the single public response. `evaluate` enriches the
existing `NoulAnswer`, `ChoiceAnswer` and `ScoreAnswer`; there is no second result
wrapper. Responses retain `raw`, `unknown_answers`, raw HTTP response, request
ID, model, usage, retry count and elapsed time. Semantic `elapsed_ms` includes
local validation, Pristine execution and decoding; `runtime_elapsed_ms` retains
Pristine's reported timing. Batch responses also carry zero-based `batch_index`.

```elixir
team = TypeSafeSDK.Response.fetch!(response, :team)
{:ok, team} = TypeSafeSDK.Response.fetch(response, :team)
TypeSafeSDK.Response.choices(response)
TypeSafeSDK.Response.nouls(response)
TypeSafeSDK.Response.scores(response)
TypeSafeSDK.Response.values(response)
# => %{urgent: 0.91, team: :billing, severity: 1.7}
```

Fetch uses exact keys, not atom/string coercion. `fetch!` lists available IDs in
its KeyError. Raw/parity responses use strings; semantic responses preserve the
caller key type. Every typed answer retains its own raw payload and ID. `Response.values/1` is a narrow convenience projection of the primary Noul/Choice/Score value; it omits unknown future answer types and does not replace the enriched answer structs.

## Relational validation

Known answers must match requested IDs and types. Choice selections and the
probability-key domain must match submitted options. Score must lie in the
requested range; legend and probability keys must match level indices. All
probabilities/confidence lie in [0,1]. Distribution sums must be within
`probability_tolerance` (default 0.02, permitted range 0..0.1); values are never
silently renormalized. Tighten to zero when your application requires exact sums
(up to the implementation's floating-point comparison epsilon).

A requested ID missing entirely is an error. An entry with an unknown future
tag is retained/skipped, even for a known question; applications must handle a
missing typed answer in that case. Unexpected known IDs fail. Negative or
noninteger usage counts fail; absent optional usage counts remain nil.
A structural/relationally valid answer can still make an incorrect judgment.

## Information helpers

```elixir
TypeSafeSDK.Answer.Choice.ranked(team)
TypeSafeSDK.Answer.Choice.margin(team)
TypeSafeSDK.Answer.confidence(team)

severity = response.answers.severity
TypeSafeSDK.Answer.Score.ranked(severity)
TypeSafeSDK.Answer.Score.expected_level(severity)
TypeSafeSDK.Answer.Score.max_level(severity)
TypeSafeSDK.Answer.Score.normalized(severity)
```

Choice ranking is descending; ties follow caller order (deterministic key order
for unenriched legacy answers). Margin is the difference between the top two
probabilities, NOT the provider's confidence. For a Score with probabilities
`%{0 => 0.45, 1 => 0.1, 2 => 0.45}` and expected score 1, the rounded expected
level is 1 but the modal helper returns 0, breaking equal probabilities toward
the lowest index. Normalization divides by the highest legend index; legacy
single-level rubrics return 0.0. Semantic scores retain original rubric labels
and descriptions while preserving the server's legend separately.

Noul has no wire confidence. `Answer.confidence(noul)` derives `max(p, 1-p)`;
that describes certainty, not whether the answer is true or safe to act on.
`Answer.yes?(noul, threshold)` compares probability of true; its convenience
default is 0.5 and is not a recommended risk policy.

## No hidden gate policy

```elixir
case TypeSafeSDK.Answer.gate(team, act: 0.90, review: 0.70) do
  :act -> :application_may_continue
  :review -> :request_review
  :escalate -> :use_fallback
end
```

Both thresholds are mandatory, with `0 <= review <= act <= 1`. These numbers are
illustrative. A confident Noul false answer can return `:act`: separately inspect
`yes?` before deciding which business action to perform. Confidence is not a
calibration guarantee. Choose thresholds from task-specific evidence and costs.

Run `mix run examples/live_semantic.exs` for a complete live walkthrough.
See [the live example catalog](../examples/README.md) for setup and API-call costs.
