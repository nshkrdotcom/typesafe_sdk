Code.require_file("support/live.exs", __DIR__)

alias TypeSafeSDK.Examples.Live
alias TypeSafeSDK.{Error, Models, Prepared, Response}

client = Live.client()
Live.show_configuration(client)

catalog = client |> TypeSafeSDK.list_models() |> Live.unwrap!()

case catalog.models do
  [] -> raise "The selected TypeSafe-compatible endpoint returned an empty model catalog"
  _ -> :ok
end

observed_model =
  case Models.find(catalog, client.default_model) do
    {:ok, model} -> model
    {:error, %Error{type: :model_not_found}} -> hd(catalog.models)
    {:error, error} -> raise error
  end

{:ok, exact_model} = Models.find(catalog, observed_model.name)
^exact_model = Models.find!(catalog.models, observed_model.name)

latest =
  case Models.latest(catalog, :all) do
    {:ok, model} ->
      %{status: :ok, name: model.name, release_date: model.release_date}

    {:error, %Error{} = error} ->
      %{status: :not_objectively_orderable, error: Error.metadata(error)}
  end

Live.show("Live model catalog helpers", %{
  catalog_size: length(catalog.models),
  exact_find: exact_model.name,
  exact_find_bang: exact_model.name,
  selected_for_calls: observed_model.name,
  latest: latest
})

base =
  TypeSafeSDK.prepare!(
    urgent: TypeSafeSDK.noul("Does this need prompt human attention?"),
    team:
      TypeSafeSDK.choice("Which team owns this request?", [
        {:billing, "Invoices, charges, and refunds"},
        {:technical, "Product failures and integrations"},
        {:sales, "Purchasing and plan questions"}
      ])
  )

same_semantics =
  TypeSafeSDK.prepare!(
    urgent: TypeSafeSDK.noul("Does this need prompt human attention?"),
    team:
      TypeSafeSDK.choice("Which team owns this request?", [
        {:billing, "Invoices, charges, and refunds"},
        {:technical, "Product failures and integrations"},
        {:sales, "Purchasing and plan questions"}
      ])
  )

{:ok, with_score} =
  Prepared.put(
    base,
    :severity,
    TypeSafeSDK.score("How much business impact is described?", ["Low", "Medium", "High"])
  )

{:ok, replaced} =
  Prepared.put(
    with_score,
    :team,
    TypeSafeSDK.choice("Which team should review this next?", [
      {:billing, "Invoices, charges, and refunds"},
      {:technical, "Product failures and integrations"},
      {:sales, "Purchasing and plan questions"}
    ])
  )

right =
  TypeSafeSDK.prepare!(
    team:
      TypeSafeSDK.choice("Which team is the final owner?", [
        {:billing, "Billing"},
        {:technical, "Technical"},
        {:sales, "Sales"}
      ]),
    review: TypeSafeSDK.noul("Should a human review the result before action?")
  )

{:ok, merged} = Prepared.merge(replaced, right)
{:ok, taken} = Prepared.take(merged, [:urgent, :severity])
{:ok, deleted} = Prepared.delete(merged, :review)

Live.show("Prepared composition", %{
  base_keys: Prepared.keys(base),
  base_count: Prepared.count(base),
  base_fingerprint: Prepared.fingerprint(base),
  stable_rebuild: Prepared.fingerprint(base) == Prepared.fingerprint(same_semantics),
  put_append_keys: Prepared.keys(with_score),
  put_replace_position: Prepared.keys(replaced),
  right_biased_merge_keys: Prepared.keys(merged),
  take_preserves_source_order: Prepared.keys(taken),
  delete_keys: Prepared.keys(deleted),
  base_was_not_mutated: Prepared.keys(base) == [:urgent, :team],
  changed_definition_changes_identity: Prepared.fingerprint(base) != Prepared.fingerprint(replaced)
})

state = %{
  subject: "Duplicate charge during an outage",
  body:
    "We were charged twice while the API was unavailable. Please investigate and refund one charge."
}

# Observe the response model before enforcing exact allowed-model membership. A
# catalog alias can resolve to a concrete response model, especially across hosts.
probe_client = Live.client(model: observed_model.name, max_request_bytes: 64_000)

probe =
  TypeSafeSDK.evaluate!(probe_client, state, merged,
    timeout_ms: 12_000,
    retry: false
  )

observed_response_model = probe.model

unless is_binary(observed_response_model) and String.trim(observed_response_model) != "" do
  raise "The live response did not provide a usable model identifier for exact contract coverage"
end

Live.show("Client-default request budget and observed response model", %{
  requested_catalog_model: observed_model.name,
  observed_response_model: observed_response_model,
  values: Response.values(probe),
  metadata: Response.metadata(probe),
  response_keys: Map.keys(probe.answers),
  raw_escape_hatch: %{
    decoded_body_keys: Map.keys(probe.raw || %{}) |> Enum.sort(),
    http_status: Response.raw_http_response!(probe).status
  }
})

contract_client =
  Live.client(
    model: observed_model.name,
    max_request_bytes: 64_000,
    response_contract: [on_unknown_answer: :error, allowed_models: [observed_response_model]]
  )

response =
  TypeSafeSDK.evaluate!(contract_client, state, merged,
    timeout_ms: 12_000,
    retry: false
  )

Live.show("Successful client-default strict response contract", %{
  allowed_models: [observed_response_model],
  on_unknown_answer: :error,
  values: Response.values(response),
  metadata: Response.metadata(response)
})

response_override =
  TypeSafeSDK.evaluate!(contract_client, state, deleted,
    max_request_bytes: 32_000,
    response_contract: [on_unknown_answer: :error, allowed_models: [observed_response_model]],
    retry: false
  )

Live.show("Per-call contract/budget override", %{
  values: Response.values(response_override),
  metadata: Response.metadata(response_override)
})

response_unlimited =
  TypeSafeSDK.evaluate!(contract_client, state, taken,
    max_request_bytes: nil,
    retry: false
  )

Live.show("Explicit nil disables the client request-byte budget for this call", %{
  values: Response.values(response_unlimited),
  metadata: Response.metadata(response_unlimited)
})

case TypeSafeSDK.evaluate(contract_client, state, merged, max_request_bytes: 1, retry: false) do
  {:error, %Error{type: :request_too_large} = error} ->
    Live.show(
      "Expected local preflight rejection (no API request for this call)",
      Error.metadata(error)
    )

  other ->
    raise "Expected a local request_too_large result, got: #{inspect(other)}"
end

IO.puts("""
The successful response contracts use an exact model identifier observed from a real response on this endpoint.
A normal successful live response cannot manufacture or prove handling of a future unknown answer
type; that deterministic branch remains covered by tests. Prepared fingerprints are computed
from local definitions only and never derive atoms from response data.
""")
