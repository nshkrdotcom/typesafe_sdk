# Models

List the models available to the account:

```elixir
{:ok, %TypeSafeSDK.ListModelsResponse{models: models}} =
  TypeSafeSDK.list_models(client)
```

Each model is a `TypeSafeSDK.ModelMetadata` with required `name`, `description`,
and `release_date` fields. Unknown future fields are ignored.

```elixir
Enum.map(models, & &1.name)

# Select a returned model name for an evaluation:
TypeSafeSDK.system_one(client, state, questions, model: "jev-latest")
```

The evaluation response reports the model that actually handled the request;
an alias such as `jev-latest` may resolve to a concrete version.

## Response metadata and reproducible evaluation

The model-list response also retains raw JSON, request ID, raw HTTP response,
retry count and elapsed milliseconds. `Test.stub_models/3` exercises the same
list-model decoding path. For repeated evaluations, choose a concrete model
version from the list rather than assuming an alias is immutable; record the
actual returned model and request IDs. The bundled evaluation workflow freezes
an observed model with its development policy for held-out runs.

## Pure catalog lookup helpers in 0.3

```elixir
{:ok, response} = TypeSafeSDK.list_models(client)
{:ok, model} = TypeSafeSDK.Models.find(response, "jev")
model = TypeSafeSDK.Models.find!(response.models, "jev")
{:ok, latest} = TypeSafeSDK.Models.latest(response, :all)
```

`find/2` is exact; it does not perform prefix or fuzzy matching and reports
ambiguity. `latest/2` uses the structured `release_date`. Selectors can be
`:all`, an exact model name, exact model-field keyword/map filters, or a unary
predicate. Invalid dates or an objective latest-date tie fail with an
`unordered_model_catalog` error rather than guessing from lexical or returned
order.
