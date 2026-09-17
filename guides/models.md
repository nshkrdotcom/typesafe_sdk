# Models

List the models available to the account:

```elixir
{:ok, %TypeSafeSDK.ListModelsResponse{models: models}} =
  TypeSafeSDK.list_models(client)
```

Each model is a `TypeSafeSDK.ModelMetadata` with required `name`, `description`,
and `release_date` fields. Unknown future fields are ignored.
