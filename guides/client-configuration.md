# Client Configuration

`TypeSafeSDK.Client.new/1` accepts:

- `:api_key` - required unless materialized into application config
- `:base_url` - TypeSafe-compatible API root; default `https://api.typesafe.ai`
- `:model` - provider model ID; default `jev-latest`
- `:timeout` - seconds, matching the Python public API
- `:timeout_ms` - explicit Elixir/Pristine millisecond form
- `:retry` - `TypeSafeSDK.RetryPolicy`, keyword/map options, or `false`
- `:response_contract` - semantic response policy
- `:max_request_bytes` - positive serialized request-byte limit or `nil`
- `:headers` - additive default headers; protected protocol headers cannot be overridden
- `:transport` / `:transport_opts` - Pristine transport injection points
- `:runtime_requirements` - required advertised transport capabilities; default `[]`

## Alternate TypeSafe-compatible endpoints

Provider selection is ordinary client configuration, not a separate transport
mode:

```elixir
client =
  TypeSafeSDK.new_client(
    api_key: provider_key,
    base_url: "https://provider.example/deployments/my-typesafe-root",
    model: "provider-model-id"
  )
```

The base URL is the root before the generated operation paths:

```text
<base_url>/v1/models
<base_url>/v1/systemone
```

Path prefixes are preserved. A base URL must be a nonblank `http` or `https` URL
with a host. URL credentials, query strings, and fragments are rejected. The
selected endpoint must implement TypeSafe's operation/request/response contract
and bearer authentication; “OpenAI-compatible” by itself is not enough. API
keys, model IDs, and supported operations are provider-specific.

This SDK does not guess Cloudflare account/deployment paths or any other
third-party provider configuration. Use a provider's documented deployment URL
and a credential issued for that same endpoint.

## Environment and host application config

The Python SDK's environment names are preserved at the configuration boundary:
`TYPESAFE_API_KEY`, `TYPESAFE_BASE_URL`, `TYPESAFE_DEFAULT_MODEL`, and
`TYPESAFE_LOG_LEVEL`.

Runtime library modules do not read the OS environment directly. Materialize
values in the **host application's** `config/runtime.exs`:

```elixir
import Config

config :typesafe_sdk,
  api_key: System.fetch_env!("TYPESAFE_API_KEY"),
  base_url: System.get_env("TYPESAFE_BASE_URL", "https://api.typesafe.ai"),
  default_model: System.get_env("TYPESAFE_DEFAULT_MODEL", "jev-latest")
```

A dependency's `config/runtime.exs` does not configure its host application.
This repository's own `config/runtime.exs` maps those names only when the
repository is the top-level application.

Precedence for library clients is:

1. explicit non-`nil` client option;
2. host application config;
3. SDK default.

The executable live examples add an intentional environment layer because they
are command-line entrypoints: explicit CLI/helper option, then `TYPESAFE_*`, then
host application config/default. Blank explicit environment endpoint/model
settings are errors rather than fallback signals. See
[the example catalog](../examples/README.md).

## Client and per-call settings

```elixir
client =
  TypeSafeSDK.new_client(
    api_key: "your-key",
    model: "jev-latest",
    timeout: 10,
    retry: [max_retries: 2]
  )

TypeSafeSDK.list_models(client, timeout: 5, retry: false)
```

The default request timeout is 10 seconds. `timeout_ms` is the explicit
millisecond alternative. Retry backoff and budget options use seconds. Per-call
settings apply only to that request; reuse the client for later calls.

Default `:headers` and per-call `:extra_headers` cannot replace protected auth,
accept, user-agent, SDK, runtime, or retry headers. Keep API keys in host secrets
and never commit them in example scripts.

## Semantic calls and batch options

`evaluate` adds `telemetry_metadata`, `probability_tolerance`, `cancellation`,
`response_contract`, and `max_request_bytes`. It rejects unknown/duplicate
options and protects `state`/`model`/`questions` against `extra_body` overrides.
The old `system_one` call retains its permissive last-write-wins `extra_body`
behavior.

Per-call retry keyword/map values inherit omitted fields from the client policy;
`retry: false` disables retries. Per-call `max_request_bytes` wins over the client
setting; explicit `nil` disables the client byte budget for that call.

`evaluate_many` / `evaluate_stream` add `max_concurrency`, `max_pending`,
`ordered`, `on_error`, `task_timeout_ms` and `attempt_timeout_ms`; see
[batching](batching.md). Task budgets do not change HTTP timeout/retry units.
Runtime capabilities are audited explicitly, never inferred from a batch
concurrency setting; see [runtime bounds](runtime-capabilities.md).

### Strict semantic header validation

`evaluate` validates `extra_headers` before transport: use a map or list of
atom/string name-value pairs. Names must be HTTP tokens; duplicate
case-insensitive names, control characters and non-stringifiable values produce
path-aware `:invalid_request` errors. Existing protected headers remain owned by
the client. Duplicate nested retry options are also rejected by the semantic
API. The legacy parity interface keeps its existing header normalization
behavior.

## Live verification

All standalone examples honor `TYPESAFE_BASE_URL` and
`TYPESAFE_DEFAULT_MODEL`; the evaluation CLI and `mix typesafe.record` also
accept explicit `--base-url` / `--model` options. The runner's real HTTP path is
fixed to Pristine's Finch adapter so endpoint configurability cannot turn a live
example into a fixture transport.

Regression coverage for endpoint precedence, invalid settings, path-prefix
joining, and protected authentication headers lives in
`test/typesafe_sdk/live_example_configuration_test.exs`,
`client_configuration_test.exs`, and `runtime_test.exs`.

See [runtime controls](runtime-controls.md) and
[the 0.3 migration guide](migration-0.3.md) for cancellation, response contracts,
request budgets, retry inheritance, model helpers, and stable metadata.
