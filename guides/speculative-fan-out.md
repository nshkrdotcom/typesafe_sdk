# Speculative Read-Only Fan-Out

Speculation can overlap independent work with an evaluation, but cancellation
cannot undo a charge, email, database write or remote side effect. Only start
read-only/idempotent candidates and keep permission to act in application code.

```elixir
# MyApp.TaskSupervisor is owned by your application supervision tree.
lookups = Task.Supervisor.async_nolink(MyApp.TaskSupervisor, fn ->
  MyApp.Search.read_only_candidates(query)
end)
try do
  case TypeSafeSDK.evaluate(client, query, useful: TypeSafeSDK.noul("Is a search useful?")) do
    {:ok, response} ->
      if TypeSafeSDK.Answer.yes?(TypeSafeSDK.Response.fetch!(response, :useful), 0.85) do
        case Task.yield(lookups, 2_000) || Task.shutdown(lookups, :brutal_kill) do
          {:ok, candidates} -> {:ok, candidates}
          _ -> {:error, :search_unavailable}
        end
      else
        {:ok, []}
      end
    {:error, error} -> {:error, error}
  end
 after
  Task.shutdown(lookups, :brutal_kill)
end
```

`MyApp.*` names represent the host application's real services, not SDK APIs.
Evaluate whether speculative cost/latency is worthwhile with actual workloads.
For many TypeSafe states, prefer the SDK's bounded evaluation stream. Killing a
local task does not prove cancellation of work already accepted by a remote API.
