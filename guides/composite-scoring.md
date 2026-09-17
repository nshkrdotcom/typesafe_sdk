# Composite Scoring

Separate dimensions make a ranking policy inspectable. Score each dimension,
normalize the expected scores, then combine with explicit application weights.

```elixir
questions = [
  relevance: TypeSafeSDK.score("How relevant is this passage?", ["Unrelated", "Partial", "Direct"]),
  clarity: TypeSafeSDK.score("How clear is this passage?", ["Unclear", "Mixed", "Clear"])
]
{:ok, response} = TypeSafeSDK.evaluate(client, passage, questions)
weights = %{relevance: 0.7, clarity: 0.3}
combined = Enum.reduce(weights, 0.0, fn {id, weight}, total ->
  answer = TypeSafeSDK.Response.fetch!(response, id)
  total + weight * TypeSafeSDK.Answer.Score.normalized(answer)
end)
```

Weights should sum to one when a [0,1] composite is intended. Do not silently drop
failed/unknown dimensions or low-confidence answers while leaving the denominator
unchanged. Define whether incomplete evidence triggers review or a separately
normalized partial score. Preserve each distribution: a bimodal Score can have
the same expectation as a confident middle-level answer. Test weights, rubric
changes and confidence policies on task-specific labeled examples.

Run `mix run examples/live_decision_patterns.exs` for a complete live walkthrough.
See [the live example catalog](../examples/README.md) for setup and API-call costs.
