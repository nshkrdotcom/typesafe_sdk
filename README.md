<p align="center">
  <img src="assets/typesafe_sdk.svg" alt="TypeSafeSDK" width="200" height="200"/>
</p>

<p align="center">
  <a href="https://hex.pm/packages/typesafe_sdk"><img src="https://img.shields.io/hexpm/v/typesafe_sdk.svg" alt="Hex.pm"/></a>
  <a href="https://hexdocs.pm/typesafe_sdk"><img src="https://img.shields.io/badge/hex-docs-blue.svg" alt="HexDocs"/></a>
  <a href="https://github.com/nshkrdotcom/typesafe_sdk"><img src="https://img.shields.io/badge/GitHub-repo-black?logo=github" alt="GitHub"/></a>
  <a href="https://hex.pm/packages/typesafe_sdk"><img src="https://img.shields.io/hexpm/l/typesafe_sdk.svg" alt="License"/></a>
</p>

# TypeSafeSDK

Elixir client for [TypeSafe AI](https://docs.typesafe.ai/introduction): evaluate
text or structured state with typed questions and receive structured answers.
Supports System One (`POST /v1/systemone`) and model listing (`GET /v1/models`).
HTTP execution, retries, and transport are provided by Pristine 0.3.0.

## Installation

```elixir
def deps do
  [{:typesafe_sdk, "~> 0.1.1"}]
end
```

## Documentation

- [Guide index](guides/index.md) — installation, configuration, and API usage.
- [Live API example](examples/README.md) — run both operations and inspect structured output.
- [Changelog](CHANGELOG.md) — release history.
- [License](LICENSE) — MIT license.

## Quick start

Read credentials in your application's `config/runtime.exs`:

```elixir
import Config
config :typesafe_sdk, api_key: System.fetch_env!("TYPESAFE_API_KEY")
```

Then create one reusable client and ask questions:

```elixir
alias TypeSafeSDK.{Choice, Noul, Score}

client = TypeSafeSDK.new_client()

{:ok, result} =
  TypeSafeSDK.system_one(
    client,
    %{"message" => "I was charged twice. Please fix this today."},
    %{
      billing: %Noul{instructions: "Is this about billing?"},
      department: Choice.new(
        %{"billing" => "Payments and invoices", "technical" => "Bugs and outages"},
        instructions: "Which team should handle this?"
      ),
      urgency: Score.new(
        ["Can wait", "This week", "Today"],
        instructions: "How urgent is this?"
      )
    }
  )

result.answers["billing"].noul
result.answers["department"].choice
result.answers["urgency"].score
result.usage.input_tokens

{:ok, available} = TypeSafeSDK.list_models(client)
Enum.map(available.models, & &1.name)
```

The default model is `"jev-latest"`. A state can be a string, object, or array.
Score criteria should contain at least two levels, as required by the live API.
Raw question maps are also accepted, preserving future question types and extra
fields. Unknown answer types are logged and skipped. Score legend and probability
keys become integers in Elixir.

## Configuration and errors

```elixir
client = TypeSafeSDK.new_client(api_key: "your-key", timeout: 10, retry: [max_retries: 2])

case TypeSafeSDK.list_models(client, timeout: 5, retry: false) do
  {:ok, response} -> response.models
  {:error, %TypeSafeSDK.Error{type: type, status: status, message: message}} ->
    {type, status, message}
end
```

Timeouts and retry backoff values are in **seconds**; `timeout_ms` is an explicit
millisecond alternative. Defaults retry connection failures, timeouts, HTTP 408,
429, and every 5xx status (including 529), with two retries, exponential backoff,
and a 30-second total retry budget. `Retry-After` and `retry-after-ms` are honored.
Client and per-call policies can replace the retry status set or disable retries.

`extra_body` shallow-merges last, including replacement of `state`, `model`, or
`questions`. `extra_headers` cannot replace authentication, content negotiation,
user-agent, or TypeSafe SDK/runtime/retry headers. Successful responses retain
`request_id` and `raw_http_response` metadata.

Library runtime modules do not read environment variables. In this checkout,
`config/runtime.exs` reads `TYPESAFE_API_KEY`, `TYPESAFE_BASE_URL`,
`TYPESAFE_DEFAULT_MODEL`, and `TYPESAFE_LOG_LEVEL`. Host applications can pass
options directly or set application configuration in their own `runtime.exs`.

## Live example

Print real model data, typed questions, structured answers, and token usage:

```bash
# With TYPESAFE_API_KEY exported, run from the repository root:
mix run examples/live_evaluation.exs
```

See [examples/README.md](https://github.com/nshkrdotcom/typesafe_sdk/blob/main/examples/README.md)
for the secrets-helper command and an explanation of the output.

## Tests

The default suite uses fixtures and a mocked transport through the real Pristine
request pipeline. It needs no API key and makes no live API calls:

```bash
mix test
```

Real API tests are tagged `:live` and opt-in. They make billable evaluation calls:

```bash
# With TYPESAFE_API_KEY exported:
mix test --only live
# Or run the complete suite, including live tests:
mix test --include live
```

## Generation and local development

The committed [OpenAPI snapshot](priv/upstream/openapi.json) was fetched from
`https://api.typesafe.ai/openapi.json` on 2026-09-16. The initial public semantic
reference is Python `typesafe-sdk` 0.6.0. See the
[provenance notes](guides/upstream-provenance.md) for reviewed schema changes.

```bash
mix deps.get
mix typesafe.prereq
mix typesafe.refresh --project-root .
mix typesafe.generate --project-root .
mix typesafe.verify --project-root .
```

Review upstream and generated diffs. Edit the source plugin or handwritten
modules, then regenerate; `lib/typesafe_sdk/generated/` is generator-owned.
Code generation tooling is compiled only in dev/test.

This is a standalone Mix application. Dependency tuples default to Hex, with the
same `MIX_WORKSPACE_OPS_BOOTSTRAP` / `workspace_dep/1` hook as the sibling SDKs for
local path or Git source selection. Local Pristine 0.3.0 can satisfy the
prerequisite without publishing it. No portfolio registry is required by this SDK.

See [HANDOFF.md](https://github.com/nshkrdotcom/typesafe_sdk/blob/main/HANDOFF.md) for local verification results and publication notes,
and [the guides](guides/getting-started.md) for more examples.

For the three-package release order and copy/paste commands, see the
[publication handoff](https://github.com/nshkrdotcom/typesafe_sdk/blob/main/PUBLISHING.md).
Pristine Codegen and Testkit are checkout-only maintenance tools; publishing the
unpacked SDK distribution does not require releasing those tools.
