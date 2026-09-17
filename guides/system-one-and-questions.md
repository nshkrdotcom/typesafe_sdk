# System One and Legacy Wire Questions

For new integrations, use [semantic questions](semantic-questions.md) and
`TypeSafeSDK.evaluate/4`. This page documents the retained `system_one/4` parity
interface, whose constructors still return legacy structs.

`TypeSafeSDK.system_one/4` evaluates text or structured JSON-compatible state and
a nonempty map of named questions.

## Noul

```elixir
%TypeSafeSDK.Noul{
  instructions: "Is this about billing?",
  criteria: %{"true" => "Payments or invoices", "false" => "Unrelated to billing"}
}
```

## Choice

```elixir
TypeSafeSDK.Choice.new(
  %{"calm" => nil, "frustrated" => nil, "angry" => nil},
  instructions: "What is the tone?"
)
```

## Score

```elixir
TypeSafeSDK.Score.new(
  ["can wait", "this week", "today"],
  instructions: "How urgent is this?"
)
```

Raw maps are accepted for forward compatibility as long as `"type"` is a
nonempty string. Choice and score maps require `criteria`; the legacy SDK checks only that score criteria are a nonempty list. The committed
OpenAPI minimum is one; the provenance notes record a stricter live server rule.
Strict semantic preparation independently requires 2..10 levels.

## Read structured answers

```elixir
{:ok, response} = TypeSafeSDK.system_one(client, state, questions)

response.answers["billing"].noul
response.answers["tone"].choice
response.answers["tone"].probabilities
response.answers["urgency"].score
response.answers["urgency"].legend
response.usage.output_tokens
```

Use the string form of the question keys with this parity API. A `NoulAnswer` contains a probability from
zero to one. A `ChoiceAnswer` contains the selected option, full probability map,
and confidence. A `ScoreAnswer` contains a weighted score, level legend,
probabilities, and confidence. Score legend and probability keys are integers;
the first criterion is level zero. Unknown future answer types are skipped in typed answers and retained in `raw`
and `unknown_answers`. Both APIs reject invalid probability ranges, negative
usage counts and normalized response-key collisions.

## Per-call options

Call options include `:model`, `:retry`, `:timeout`, `:timeout_ms`,
`:extra_headers`, and `:extra_body`. `extra_body` is a shallow last-write-wins
merge, matching the supplied Python SDK.
