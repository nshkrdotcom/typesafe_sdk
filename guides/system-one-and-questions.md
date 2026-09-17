# System One And Questions

`TypeSafeSDK.system_one/4` evaluates text or structured JSON-compatible state and
a nonempty map of named questions.

## Noul

```elixir
%TypeSafeSDK.Noul{
  instructions: "Is this about billing?",
  criteria: %{"true" => %{"meaning" => "Payments or invoices"}}
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
nonempty.

Call options include `:model`, `:retry`, `:timeout`, `:timeout_ms`,
`:extra_headers`, and `:extra_body`. `extra_body` is a shallow last-write-wins
merge, matching the supplied Python SDK.
