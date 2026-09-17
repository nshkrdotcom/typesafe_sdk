# Getting Started

## Install

Add the SDK to your application's `mix.exs` dependencies:

```elixir
{:typesafe_sdk, "~> 0.1.2"}
```

Run `mix deps.get`. Pristine is installed as a runtime dependency automatically.

## Configure credentials

Read your API key at your application's configuration boundary:

```elixir
# config/runtime.exs
import Config
config :typesafe_sdk, api_key: System.fetch_env!("TYPESAFE_API_KEY")
```

Create one reusable client. Calls return `{:ok, response}` or `{:error, error}`.

```elixir
client = TypeSafeSDK.new_client()
{:ok, models} = TypeSafeSDK.list_models(client)
```

## Evaluate content

The default model is `jev-latest`. State may be a string, map, or list:

```elixir
questions = %{
  billing: %TypeSafeSDK.Noul{instructions: "Is this about billing?"},
  tone: TypeSafeSDK.Choice.new(%{"calm" => nil, "angry" => nil}, instructions: "Tone?")
}

{:ok, response} = TypeSafeSDK.system_one(client, "I was charged twice", questions)

response.answers["billing"].noul
response.answers["tone"].choice
response.usage.input_tokens
```

Question keys in decoded answers are strings, including when input keys are atoms.
See [System One and questions](system-one-and-questions.md) for all three types,
[errors and retries](errors-and-retries.md) for failure handling, and the
[live example](../examples/README.md) for a complete runnable script.
