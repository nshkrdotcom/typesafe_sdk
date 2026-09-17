# Confidence-Gated Routing

Treat the selected answer and the willingness to act as different decisions.
Use a Choice for the narrow judgment; keep action permissions and thresholds in
ordinary application code.

```elixir
{:ok, response} = TypeSafeSDK.evaluate(client, ticket_text,
  team: TypeSafeSDK.choice("Which support team?", billing: "Payments", technical: "Product"))
team = TypeSafeSDK.Response.fetch!(response, :team)
case TypeSafeSDK.Answer.gate(team, act: 0.90, review: 0.70) do
  :act -> {:route_candidate, team.choice}
  :review -> {:human_review, TypeSafeSDK.Answer.Choice.ranked(team)}
  :escalate -> {:fallback, :insufficient_evidence}
end
```

The numbers illustrate the API, not a calibrated deployment policy. A large
margin answers a different question than provider confidence. Inspect competing
alternatives, use labeled data and include a route for unknown/future answers or
request failure. No helper executes business side effects; the application's
permissions and deterministic rules remain authoritative. See the evaluation
workflow for coverage/error tradeoffs and held-out validation.
