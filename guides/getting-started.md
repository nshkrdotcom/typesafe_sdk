# Getting Started with 0.4.0

## Install and select a provider

Add `{:typesafe_sdk, "~> 0.4.0"}` to your application's dependencies once this
release is published. For a local checkout before publication, use
`{:typesafe_sdk, path: "../typesafe_sdk"}`. Pristine `~> 0.4.0` owns HTTP
execution, retries, and verified unary cancellation.

The default API root/model are `https://api.typesafe.ai` and `jev-latest`. To use
another TypeSafe-compatible deployment, provide the URL, credential, and model
issued for that provider:

```bash
export TYPESAFE_API_KEY='credential-issued-for-this-endpoint'
export TYPESAFE_BASE_URL='https://provider.example/deployments/my-typesafe-root'
export TYPESAFE_DEFAULT_MODEL='provider-model-id'
```

`TYPESAFE_BASE_URL` is the root **before** `/v1/models` and `/v1/systemone`; path
prefixes are retained. The provider must implement the TypeSafe request/response
and bearer-auth contract. An arbitrary OpenAI-compatible endpoint is not
automatically TypeSafe-compatible. Do not send a credential from one provider to
a guessed third-party host.

Map the environment in your **host application's** `config/runtime.exs`:

```elixir
import Config

config :typesafe_sdk,
  api_key: System.fetch_env!("TYPESAFE_API_KEY"),
  base_url: System.get_env("TYPESAFE_BASE_URL", "https://api.typesafe.ai"),
  default_model: System.get_env("TYPESAFE_DEFAULT_MODEL", "jev-latest")
```

A dependency's runtime config does not configure its host. Runtime modules in
TypeSafeSDK do not read OS environment values themselves.

For code that should make provider selection explicit, construct the client
directly instead:

```elixir
client =
  TypeSafeSDK.new_client(
    api_key: provider_key,
    base_url: "https://provider.example/deployments/my-typesafe-root",
    model: "provider-model-id"
  )
```

Explicit client options win over host config. Blank/invalid endpoint or model
values fail instead of silently falling back to a different provider.

## First semantic evaluation

```elixir
client = TypeSafeSDK.new_client()

questions = [
  urgent: TypeSafeSDK.noul("Does this need immediate attention?"),
  team:
    TypeSafeSDK.choice("Which team owns this request?",
      billing: "Payments and invoices",
      technical: "Bugs and outages"
    ),
  severity: TypeSafeSDK.score("Severity?", ["Routine", "Important", "Blocking"])
]

{:ok, response} =
  TypeSafeSDK.evaluate(client, "The API is down for every customer", questions)

response.answers.team.choice
response.answers.severity.label
response.usage.input_tokens
```

Atom question/option keys return as the same atoms. String keys remain strings;
unknown remote strings never create atoms. The SDK returns the same
`SystemOneResponse` struct for both semantic and legacy APIs.

Use `Question.Choice.new/3`, `Question.Noul.new/2` and `Question.Score.new/3` for
runtime input that should return validation errors rather than raise. Top-level
helpers and `new!` constructors raise for invalid programmer-defined questions.
`evaluate!` and `system_one!` similarly raise normalized request errors.

Run `bash examples/run_all.sh` for the complete live walkthrough, or see the
[live example catalog](../examples/README.md) for a 0.2-0.4 feature matrix and
alternate-endpoint workflow.

## Legacy parity surface

Existing `TypeSafeSDK.Noul`, `Choice` and `Score` constructors remain unchanged.
`system_one(client, state, %{q: legacy_question})` still returns string-keyed
answers. Use [the 0.3 migration guide](migration-0.3.md) for runtime controls and
[the 0.2 migration guide](migration-0.2.md) when moving legacy application code
to `evaluate`; do not replace legacy constructor calls with tuple destructuring.

Continue with [client configuration](client-configuration.md),
[questions](semantic-questions.md), [answers](answers-and-confidence.md),
[batching](batching.md), [testing](testing.md), the
[evaluation workflow](evaluating-decisions.md), and
[runtime controls](runtime-controls.md).
