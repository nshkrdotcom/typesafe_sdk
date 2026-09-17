# System One And Questions

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
nonempty string. Choice and score maps require `criteria`; score criteria must be
contain at least two levels for the live API.

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

Use the question keys you supplied. A `NoulAnswer` contains a probability from
zero to one. A `ChoiceAnswer` contains the selected option, full probability map,
and confidence. A `ScoreAnswer` contains a weighted score, level legend,
probabilities, and confidence. Score legend and probability keys are integers;
the first criterion is level zero. Unknown future answer types are skipped.

## Per-call options

Call options include `:model`, `:retry`, `:timeout`, `:timeout_ms`,
`:extra_headers`, and `:extra_body`. `extra_body` is a shallow last-write-wins
merge, matching the supplied Python SDK.
