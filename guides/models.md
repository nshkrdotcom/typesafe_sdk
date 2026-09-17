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
