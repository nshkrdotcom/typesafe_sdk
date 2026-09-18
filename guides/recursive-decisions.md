# Recursive Decision Patterns

Fast typed decisions become more useful when one result defines the next
question. TypeSafeSDK 0.4.0 documents these patterns explicitly; the SDK does not
introduce a separate workflow engine. Use ordinary functions, `TypeSafeSDK.evaluate/4`,
`Prepared`, cancellation, supervisors, or `TypeSafeSDK.OTP.Server` as appropriate.

These patterns were informed in part by the recursive-workflow examples in
[dannote/jev](https://github.com/dannote/jev). The implementations below retain
TypeSafeSDK's bounded/runtime separation rather than copying Jev's transport.

## Hierarchical descent

For a classification space larger than one Choice request should reasonably
contain, ask one level at a time. The selected child narrows the next Choice.
Always enforce an application-owned depth bound and confidence policy.

```elixir
def descend(client, state, node, depth, max_depth) when depth < max_depth do
  children = children(node)

  if length(children) < 2 do
    {:ok, node}
  else
    options =
      children
      |> Enum.with_index()
      |> Enum.map(fn {child, index} -> {Integer.to_string(index), summary(child)} end)

    with {:ok, response} <-
           TypeSafeSDK.evaluate(client, state,
             child: TypeSafeSDK.choice("Which child is the best match?", options)
           ),
         answer <- TypeSafeSDK.Response.fetch!(response, :child),
         :act <- TypeSafeSDK.Answer.gate(answer, act: 0.85, review: 0.65),
         {index, ""} <- Integer.parse(answer.choice) do
      descend(client, state, Enum.at(children, index), depth + 1, max_depth)
    else
      _ -> {:ok, node}
    end
  end
end
```

## Bisection

Search large text or ordered spaces in logarithmic rounds rather than scoring
every element. Ask about both halves in one evaluation, recurse only into halves
that pass an explicit threshold, and stop when the chunk reaches a deterministic
size bound. If both halves qualify, use a supervisor or bounded batch to explore
them concurrently rather than spawning unbounded tasks.

## Verify and repair

For extraction from a finite candidate set, separate selection from verification:

1. choose one candidate per field;
2. ask a Noul verification question where `true` means the candidate is wrong;
3. remove rejected candidates;
4. repeat only the failed fields.

The shrinking candidate set gives the workflow a structural termination bound.
Also keep an explicit round limit for malformed data and treat exhausted
candidate sets as deterministic failures instead of asking indefinitely.

## Coarse-to-fine cascade

Ask a broad, cheap question first. If the response does not meet the application's
confidence/margin requirement, construct a narrower Choice from the strongest
remaining candidates and optionally select a different model for the second call.
Do not encode universal confidence thresholds in the SDK; tune them from labeled
development data and freeze policy before held-out evaluation.

## Clarifying conversations

When a decision is not strong enough to act, the application can ask the human a
clarifying question, append the reply to application state, and evaluate the same
intent again. Bound the number of turns and persist conversational state outside
a transient GenServer when losing a turn would be unacceptable.

## Recursive OTP workflows

`TypeSafeSDK.OTP.Server` can express the same loop by returning another
`{:evaluate, ...}` from `handle_evaluation/3`. Its `max_in_flight` bound applies to
the whole server, so recursive fan-out cannot silently create unlimited local
workers. For durable or distributed workflows, use the application's existing
workflow/supervision system and keep TypeSafeSDK as the decision primitive.

## Runnable live patterns

`mix run examples/live_recursive_decisions.exs` executes all five patterns above
against the selected real endpoint: two-level hierarchical descent, two-round
bisection, verify/repair with a shrinking candidate set, a coarse-to-fine cascade,
and a clarifying conversation capped at two turns. The script has a hard upper
bound of 12 API requests and reports its actual request count. No branch substitutes
canned model outputs or a fake fallback.

For recursion inside the OTP facade, `mix run examples/live_otp_server.exs` launches
a bounded follow-up evaluation from `handle_evaluation/3`.
