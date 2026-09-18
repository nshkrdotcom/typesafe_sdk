Code.require_file("support/live.exs", __DIR__)
alias TypeSafeSDK.Examples.Live
alias TypeSafeSDK.{Answer, Response}

client = Live.client()
Live.show_configuration(client)
IO.puts("Two live evaluations: composite scoring and speculative read-only model lookup.")

response =
  TypeSafeSDK.evaluate!(
    client,
    %{
      query: "How do I request a refund?",
      passage: "Open Billing, select the invoice, and choose Request refund."
    },
    relevance: TypeSafeSDK.score("Relevance to the query?", ["Unrelated", "Partial", "Direct"]),
    clarity: TypeSafeSDK.score("Clarity of the instructions?", ["Unclear", "Mixed", "Clear"])
  )

weights = %{relevance: 0.7, clarity: 0.3}

combined =
  Enum.reduce(weights, 0.0, fn {id, weight}, total ->
    total + weight * Answer.Score.normalized(Response.fetch!(response, id))
  end)

Live.show("Composite score with explicit weights", %{
  score: combined,
  weights: weights,
  metadata: Live.summary(response)
})

{:ok, supervisor} = Task.Supervisor.start_link()
lookup = Task.Supervisor.async_nolink(supervisor, fn -> TypeSafeSDK.list_models(client) end)

try do
  decision =
    TypeSafeSDK.evaluate!(client, "Which TypeSafe models are available?",
      useful:
        TypeSafeSDK.noul("Would a list of available TypeSafe models help answer this request?")
    )

  answer = Response.fetch!(decision, :useful)

  Live.show("Explicit decision", %{
    useful: Answer.yes?(answer, 0.85),
    certainty: Answer.confidence(answer),
    gate: Answer.gate(answer, act: 0.9, review: 0.7)
  })

  if Answer.yes?(answer, 0.85) do
    case Task.yield(lookup, 15_000) || Task.shutdown(lookup, :brutal_kill) do
      {:ok, result} -> Live.show("Live speculative model lookup", Live.unwrap!(result).models)
      _ -> raise "Speculative model lookup did not complete"
    end
  else
    IO.puts("Model lookup is not needed under the illustrative 0.85 threshold.")
  end
after
  Task.shutdown(lookup, :brutal_kill)
  Supervisor.stop(supervisor)
end
