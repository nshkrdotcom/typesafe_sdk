Code.require_file("support/live.exs", __DIR__)
alias TypeSafeSDK.Examples.Live

client = Live.client()
prepared = TypeSafeSDK.prepare!(urgent: TypeSafeSDK.noul("Does this describe an active outage?"))

states = [
  "Production API is unavailable.",
  "Please send last month's invoice.",
  "All users cannot sign in."
]

IO.puts("Ordered collection: three live evaluations, bounded to two workers.")

results =
  TypeSafeSDK.evaluate_many(client, states, prepared,
    max_concurrency: 2,
    max_pending: 2,
    ordered: true,
    on_error: :collect,
    task_timeout_ms: 30_000,
    attempt_timeout_ms: 15_000
  )

Enum.each(results, fn result ->
  response = Live.unwrap!(result)

  Live.show("Ordered result", %{
    input: Enum.at(states, response.batch_index),
    metadata: Live.summary(response)
  })
end)

IO.puts("Unordered stream: associate by batch_index, never by completion position.")

TypeSafeSDK.evaluate_stream(client, states, prepared,
  max_concurrency: 2,
  ordered: false,
  on_error: :raise,
  task_timeout_ms: 30_000,
  attempt_timeout_ms: 15_000
)
|> Enum.each(fn {:ok, response} ->
  Live.show("Unordered result", %{
    input: Enum.at(states, response.batch_index),
    metadata: Live.summary(response)
  })
end)

IO.puts("Early halt: take one result; already-submitted requests may still be processed/billed.")

TypeSafeSDK.evaluate_stream(client, states, prepared,
  max_concurrency: 2,
  max_pending: 2,
  task_timeout_ms: 30_000,
  attempt_timeout_ms: 15_000
)
|> Enum.take(1)
|> Enum.each(fn result -> Live.show("First result", result |> Live.unwrap!() |> Live.summary()) end)

IO.puts("Task budgets bound local workers; they do not prove physical or remote cancellation.")
