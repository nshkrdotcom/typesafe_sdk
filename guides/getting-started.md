# Getting Started with 0.2.0

## Install and configure

Add `{:typesafe_sdk, "~> 0.2.0"}` to your application's dependencies once this
release is published. For a local checkout before publication, use
`{:typesafe_sdk, path: "../typesafe_sdk"}`. Pristine remains the runtime dependency.

```elixir
# Your host application's config/runtime.exs
import Config
config :typesafe_sdk, api_key: System.fetch_env!("TYPESAFE_API_KEY")
```

```elixir
client = TypeSafeSDK.new_client()
questions = [
  urgent: TypeSafeSDK.noul("Does this need immediate attention?"),
  team: TypeSafeSDK.choice("Which team owns this request?",
    billing: "Payments and invoices", technical: "Bugs and outages"),
  severity: TypeSafeSDK.score("Severity?", ["Routine", "Important", "Blocking"])
]
{:ok, response} = TypeSafeSDK.evaluate(client, "The API is down for every customer", questions)
response.answers.team.choice
response.answers.severity.label
response.usage.input_tokens
```

Atom question/option keys return as the same atoms. String keys remain strings;
unknown remote strings never create atoms. The SDK returns the same
`SystemOneResponse` struct for both semantic and legacy APIs.

Use `Question.Choice.new/3`, `Question.Noul.new/2` and `Question.Score.new/3` for
runtime input that should return validation errors rather than raise.
Top-level helpers and `new!` constructors raise for invalid programmer-defined
questions. `evaluate!` and `system_one!` similarly raise normalized request errors.

## Legacy parity surface

Existing `TypeSafeSDK.Noul`, `Choice` and `Score` constructors remain unchanged.
`system_one(client, state, %{q: legacy_question})` still returns string-keyed
answers. Use [migration](migration-0.2.md) when moving application code to
`evaluate`; do not replace legacy constructor calls with tuple destructuring.

Continue with [questions](semantic-questions.md), [answers](answers-and-confidence.md),
[batching](batching.md), [testing](testing.md) and the [evaluation workflow](evaluating-decisions.md).
