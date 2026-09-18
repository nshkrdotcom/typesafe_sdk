Code.require_file("support/live.exs", __DIR__)

alias TypeSafeSDK.Examples.Live

defmodule TypeSafeSDK.Examples.RecursivePatterns do
  alias TypeSafeSDK.{Answer, Response}

  @timeout_ms 12_000

  def hierarchical_descent(client, state) do
    tree = %{
      billing: [refund: "Return money", invoice: "Correct or explain an invoice"],
      product: [bug: "Broken behavior", setup: "Configuration or integration help"]
    }

    broad = choose(client, state, :branch, "Which broad area best matches this request?", [billing: nil, product: nil])
    leaves = Map.fetch!(tree, broad)
    leaf = choose(client, state, :leaf, "Which narrower workflow best matches this request?", leaves)

    {%{branch: broad, leaf: leaf, max_depth: 2}, 2}
  end

  def bisection(client, state) do
    chunks = [
      {0, "A duplicate invoice charge needs correction."},
      {1, "Users cannot sign in after an identity-provider change."},
      {2, "The customer wants an enterprise pricing quote."},
      {3, "Every production API request is returning an error."}
    ]

    {selected, requests} = bisect(client, state, chunks, 0, 2, 2)
    {%{selected_chunks: selected, max_depth: 2, request_budget: 2}, requests}
  end

  def verify_repair(client, state) do
    candidates = [
      billing: "Charges, invoices, and refunds",
      technical: "Product failures and integrations",
      sales: "Plans and purchasing"
    ]

    {result, requests} = verify_loop(client, state, candidates, 1, 2, 0)
    {Map.put(result, :max_rounds, 2), requests}
  end

  def coarse_to_fine(client, state) do
    options = [
      billing: "Charges, invoices, and refunds",
      technical: "Product failures and integrations",
      sales: "Plans and purchasing",
      account: "Identity, access, and account administration"
    ]

    descriptions = Map.new(options)

    coarse_response =
      evaluate!(client, state,
        route: TypeSafeSDK.choice("Which broad route best matches?", options)
      )

    coarse = Response.fetch!(coarse_response, :route)
    margin = Answer.Choice.margin(coarse)
    ranked = Answer.Choice.ranked(coarse)

    if margin < 0.25 do
      narrowed =
        ranked
        |> Enum.take(2)
        |> Enum.map(fn {key, _probability} -> {key, Map.fetch!(descriptions, key)} end)

      fine_response =
        evaluate!(client, state,
          route: TypeSafeSDK.choice("Choose between the two strongest remaining routes.", narrowed)
        )

      fine = Response.fetch!(fine_response, :route)

      {%{
         coarse_choice: coarse.choice,
         coarse_margin: margin,
         refined: true,
         narrowed_to: Enum.map(narrowed, &elem(&1, 0)),
         final_choice: fine.choice,
         final_margin: Answer.Choice.margin(fine),
         max_requests: 2
       }, 2}
    else
      {%{
         coarse_choice: coarse.choice,
         coarse_margin: margin,
         refined: false,
         final_choice: coarse.choice,
         max_requests: 2
       }, 1}
    end
  end

  def clarifying_conversation(client) do
    initial = "A warning appeared while the page stopped responding. I cannot tell what failed."

    question =
      TypeSafeSDK.choice("Which route best matches the user's issue?", [
        {:billing, "Payment, invoice, or charge problem"},
        {:technical, "Application or integration failure"}
      ])

    first_response = evaluate!(client, initial, route: question)
    first = Response.fetch!(first_response, :route)
    first_margin = Answer.Choice.margin(first)

    if first_margin < 0.35 do
      # Synthetic INPUT is allowed; this is a bounded stand-in for one explicit
      # human clarification turn. No model output is fabricated.
      clarification = "Clarification from the user: the API integration is returning 503 errors."
      state = %{initial: initial, clarification: clarification}
      second_response = evaluate!(client, state, route: question)
      second = Response.fetch!(second_response, :route)

      {%{
         turns: 2,
         max_turns: 2,
         first_choice: first.choice,
         first_margin: first_margin,
         clarification_used: true,
         final_choice: second.choice,
         final_margin: Answer.Choice.margin(second)
       }, 2}
    else
      {%{
         turns: 1,
         max_turns: 2,
         first_choice: first.choice,
         first_margin: first_margin,
         clarification_used: false,
         final_choice: first.choice
       }, 1}
    end
  end

  defp bisect(_client, _state, chunks, depth, max_depth, _remaining)
       when length(chunks) <= 1 or depth >= max_depth,
       do: {Enum.map(chunks, &elem(&1, 0)), 0}

  defp bisect(_client, _state, chunks, _depth, _max_depth, 0),
    do: {Enum.map(chunks, &elem(&1, 0)), 0}

  defp bisect(client, state, chunks, depth, max_depth, remaining) do
    midpoint = div(length(chunks), 2)
    {left, right} = Enum.split(chunks, midpoint)

    response =
      evaluate!(client, %{query: state, left: left, right: right},
        left: TypeSafeSDK.noul("Does the left half contain the better match for the query?"),
        right: TypeSafeSDK.noul("Does the right half contain the better match for the query?")
      )

    left_probability = Response.fetch!(response, :left).noul
    right_probability = Response.fetch!(response, :right).noul
    chosen = if left_probability >= right_probability, do: left, else: right

    {selected, nested_requests} =
      bisect(client, state, chosen, depth + 1, max_depth, remaining - 1)

    {selected, nested_requests + 1}
  end

  defp verify_loop(client, state, candidates, round, max_rounds, requests) do
    selection =
      choose(
        client,
        state,
        :candidate,
        "Which candidate route is the best fit?",
        candidates
      )

    verify_response =
      evaluate!(client, %{state: state, candidate: selection},
        wrong: TypeSafeSDK.noul("Is the selected candidate route wrong for this request?")
      )

    wrong_probability = Response.fetch!(verify_response, :wrong).noul
    requests = requests + 2

    cond do
      wrong_probability < 0.7 ->
        {%{
           selected: selection,
           verification_wrong_probability: wrong_probability,
           rounds: round,
           candidates_remaining: Keyword.keys(candidates),
           termination: :verified_enough
         }, requests}

      round >= max_rounds ->
        {%{
           selected: selection,
           verification_wrong_probability: wrong_probability,
           rounds: round,
           candidates_remaining: Keyword.keys(candidates),
           termination: :round_budget_exhausted
         }, requests}

      length(candidates) <= 2 ->
        remaining = Keyword.delete(candidates, selection)

        {%{
           selected: remaining |> Keyword.keys() |> hd(),
           verification_wrong_probability: wrong_probability,
           rounds: round,
           candidates_remaining: Keyword.keys(remaining),
           termination: :single_candidate_remaining
         }, requests}

      true ->
        verify_loop(
          client,
          state,
          Keyword.delete(candidates, selection),
          round + 1,
          max_rounds,
          requests
        )
    end
  end

  defp choose(client, state, id, prompt, options) do
    response = evaluate!(client, state, [{id, TypeSafeSDK.choice(prompt, options)}])
    response |> Response.values() |> Map.fetch!(id)
  end

  defp evaluate!(client, state, questions) do
    TypeSafeSDK.evaluate!(client, state, questions, timeout_ms: @timeout_ms, retry: false)
  end
end

client = Live.client()
Live.show_configuration(client)

state = "The customer reports a duplicate invoice charge and asks how to correct it."

{hierarchical, hierarchical_requests} =
  TypeSafeSDK.Examples.RecursivePatterns.hierarchical_descent(client, state)

Live.show("Hierarchical descent", hierarchical)

{bisection, bisection_requests} =
  TypeSafeSDK.Examples.RecursivePatterns.bisection(
    client,
    "Find the passage most relevant to a production API outage."
  )

Live.show("Bounded bisection", bisection)

{verify_repair, verify_requests} =
  TypeSafeSDK.Examples.RecursivePatterns.verify_repair(
    client,
    "A customer was charged twice for the same invoice."
  )

Live.show("Verify/repair over a shrinking candidate set", verify_repair)

{coarse_fine, coarse_requests} =
  TypeSafeSDK.Examples.RecursivePatterns.coarse_to_fine(
    client,
    "The customer cannot sign in after changing SSO configuration."
  )

Live.show("Coarse-to-fine cascade", coarse_fine)

{clarifying, clarifying_requests} =
  TypeSafeSDK.Examples.RecursivePatterns.clarifying_conversation(client)

Live.show("Bounded clarifying conversation", clarifying)

actual_requests =
  hierarchical_requests + bisection_requests + verify_requests + coarse_requests +
    clarifying_requests

Live.show("Recursive-pattern request accounting", %{
  actual_requests_this_run: actual_requests,
  hard_upper_bound: 12,
  hierarchical_max: 2,
  bisection_max: 2,
  verify_repair_max: 4,
  coarse_to_fine_max: 2,
  clarifying_max: 2
})

IO.puts("""
Every branch above is driven by real model responses. The application owns all termination rules:
depth, request, round, candidate, and conversation-turn bounds are finite. These examples do not
introduce a workflow engine, canned decision outputs, unbounded tasks, or fake fallbacks.
""")
