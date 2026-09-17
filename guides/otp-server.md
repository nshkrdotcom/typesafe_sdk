# Bounded OTP Server Integration

TypeSafeSDK 0.4.0 adds `TypeSafeSDK.OTP.Server`, an opt-in GenServer facade for
applications that want semantic evaluations to behave like asynchronous OTP work.
It is inspired by the peer-process design in [dannote/jev](https://github.com/dannote/jev),
but keeps TypeSafeSDK's existing response structs, Pristine runtime, cancellation
contracts, and explicit bounds.

The base SDK still starts no application process. Your application owns the
`Task.Supervisor` and chooses the per-server `max_in_flight` bound.

```elixir
defmodule MyApp.Triage do
  use TypeSafeSDK.OTP.Server

  @impl true
  def init(_), do: {:ok, %{handled: 0}}

  @impl true
  def handle_call({:route, ticket}, from, state) do
    questions = [
      team: TypeSafeSDK.choice("Which team?", billing: nil, support: nil)
    ]

    {:evaluate, {from, ticket, questions}, state}
  end

  @impl true
  def handle_evaluation({:ok, response}, from, state) do
    GenServer.reply(from, {:ok, TypeSafeSDK.Response.values(response)})
    {:noreply, %{state | handled: state.handled + 1}}
  end

  def handle_evaluation({:error, error}, from, state) do
    GenServer.reply(from, {:error, error})
    {:noreply, state}
  end
end
```

Put the task supervisor before the semantic server in the application tree:

```elixir
children = [
  {Task.Supervisor, name: MyApp.TypeSafeTasks, max_children: 64},
  {MyApp.Triage,
   client: typesafe_client,
   task_supervisor: MyApp.TypeSafeTasks,
   max_in_flight: 32,
   init_arg: nil,
   name: MyApp.Triage}
]
```

## Callback contract

Ordinary GenServer returns keep their usual meaning. To launch semantic work,
return one of these from `handle_call/3`, `handle_cast/2`, `handle_info/2`,
`handle_continue/2`, or `handle_evaluation/3`:

```elixir
{:evaluate, {tag, semantic_state, questions}, new_state}
{:evaluate, {tag, semantic_state, questions, request_options}, new_state}
```

`tag` is opaque and is returned unchanged to `handle_evaluation/3`. It is never
automatically added to telemetry. Passing the `from` argument from
`handle_call/3` lets the eventual callback answer with `GenServer.reply/2`.
Returning another `{:evaluate, ...}` from `handle_evaluation/3` creates a bounded
recursive decision workflow without blocking the server.

Server-level `evaluation_options:` are merged with request-specific options, with
the request-specific value winning. Those options go through the same
option-validation path as direct `TypeSafeSDK.evaluate/4` calls.

## Bounds and lifecycle

`max_in_flight` defaults to 32 and accepts 1..1024. Once the bound is reached,
new semantic work is returned to `handle_evaluation/3` as a normalized
`%TypeSafeSDK.Error{type: :runtime_capability}` instead of creating another task.
This is a per-server bound, not a claim about the shared HTTP transport queue.

Every request is executed with a private `Pristine.Cancellation` token owned by
the wrapper. If the caller supplies `cancellation:`, a temporary Pristine watcher
mirrors caller cancellation into that private token; the caller's token itself is
never mutated by the server. The wrapper traps exits so orderly supervisor
shutdown runs its cleanup path, stops the watcher, cancels the private token, and
then stops the corresponding local task. This lets transport cleanup use
cancellation without stealing ownership of an application token. As elsewhere in
the SDK, local cancellation does not prove the remote service never accepted or
processed a request.

A server restart rebuilds its in-memory pending map. Do not use an in-memory OTP
wrapper as durable workflow state: persist the position externally when a
multi-step workflow must resume after process restart.

`format_status/1` exposes only the inner application state plus `in_flight` and
`max_in_flight`; client credentials, pending tags, cancellation tokens, and task
records are not shown.
