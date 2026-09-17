# Client Configuration

`TypeSafeSDK.Client.new/1` accepts:

- `:api_key` - required unless materialized into application config
- `:base_url` - default `https://api.typesafe.ai`
- `:model` - default `jev-latest`
- `:timeout` - seconds, matching the Python public API
- `:timeout_ms` - explicit Elixir/Pristine millisecond form
- `:retry` - `TypeSafeSDK.RetryPolicy`, keyword/map options, or `false`
- `:headers` - additive default headers; protected protocol headers cannot be overridden
- `:transport` / `:transport_opts` - Pristine transport injection points

The Python SDK's environment names are preserved at the configuration boundary:
`TYPESAFE_API_KEY`, `TYPESAFE_BASE_URL`, `TYPESAFE_DEFAULT_MODEL`, and
`TYPESAFE_LOG_LEVEL`.

Runtime library modules do not read the OS environment directly. For a consumer
application, materialize values in the host `config/runtime.exs` and pass them to
`:typesafe_sdk`, or pass explicit client options.

## Client and per-call settings

```elixir
client = TypeSafeSDK.new_client(
  api_key: "your-key",
  model: "jev-latest",
  timeout: 10,
  retry: [max_retries: 2]
)

TypeSafeSDK.list_models(client, timeout: 5, retry: false)
```

The default request timeout is 10 seconds. `timeout_ms` is the explicit
millisecond alternative. Retry backoff and budget options use seconds.
Per-call settings apply only to that request; reuse the client for subsequent calls.

Default `:headers` and per-call `:extra_headers` cannot replace protected auth,
accept, user-agent, SDK, runtime, or retry headers. Keep the API key in host
configuration and never commit it in example scripts.
