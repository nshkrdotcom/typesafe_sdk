# Getting Started

Add `typesafe_sdk` and construct one client. The API returns tagged tuples rather
than raising for network/API failures.

```elixir
client = TypeSafeSDK.new_client(api_key: "ts_...")
{:ok, models} = TypeSafeSDK.list_models(client)
```

For System One:

```elixir
questions = %{
  billing: %TypeSafeSDK.Noul{instructions: "Is this about billing?"},
  tone: TypeSafeSDK.Choice.new(%{"calm" => nil, "angry" => nil}, instructions: "Tone?")
}

{:ok, response} = TypeSafeSDK.system_one(client, "I was charged twice", questions)
```

See the configuration and System One guides for overrides and response helpers.
