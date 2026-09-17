Code.require_file("support/live.exs", __DIR__)
alias TypeSafeSDK.Examples.Live
alias TypeSafeSDK.Response

client = Live.client()
state = "The customer says a duplicate invoice was charged and asks how to correct it."

tree = %{
  billing: [refund: "Return money", invoice: "Correct or explain an invoice"],
  product: [bug: "Broken behavior", setup: "Configuration or integration help"]
}

choose = fn id, prompt, options ->
  response =
    TypeSafeSDK.evaluate!(
      client,
      state,
      [{id, TypeSafeSDK.choice(prompt, options)}],
      retry: false,
      timeout_ms: 15_000
    )

  response |> Response.values() |> Map.fetch!(id)
end

branch =
  choose.(
    :branch,
    "Which broad area best matches this request?",
    [billing: nil, product: nil]
  )
leaves = Map.fetch!(tree, branch)
leaf = choose.(:leaf, "Which narrower workflow best matches this request?", leaves)

Live.show("Two-level bounded descent", %{branch: branch, leaf: leaf})
IO.puts(
  "Each level is a separate semantic request; " <>
    "production recursion still needs explicit depth/policy bounds."
)
