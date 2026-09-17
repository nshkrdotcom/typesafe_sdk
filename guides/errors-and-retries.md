# Errors And Retries

Network/API calls return `{:ok, value}` or `{:error, %TypeSafeSDK.Error{}}`.

```elixir
case TypeSafeSDK.list_models(client) do
  {:ok, response} ->
    Enum.map(response.models, & &1.name)

  {:error, %TypeSafeSDK.Error{type: type, status: status, message: message}} ->
    IO.inspect(%{type: type, status: status, message: message}, label: "API failure")
end
```

`error.type` uses these primary values:

- `:bad_request` (400)
- `:authentication` (401)
- `:permission_denied` (403)
- `:not_found` (404)
- `:unprocessable_entity` (422)
- `:rate_limit` (429)
- `:internal_server` (5xx)
- `:api_error` for other unsuccessful statuses
- `:connection`, `:timeout`, `:response_validation`, `:configuration`

The error also preserves status, body, headers, TypeSafe request ID, retry-after
milliseconds, the raw `Pristine.Response`, and an endpoint string when Pristine
transport metadata provides it. Successful `SystemOneResponse` and
`ListModelsResponse` values likewise retain `request_id` and `raw_http_response`;
use their `request_id!/1` / `raw_http_response!/1` accessors when metadata is
required rather than optional.

`TypeSafeSDK.RetryPolicy` defaults to the supplied Python SDK's public values:
two retries, 0.5-second exponential initial backoff, 5-second cap, 0.25 jitter,
retrying 408/429/5xx plus connection/timeouts, honoring Retry-After, and a
30-second retry budget. The budget includes the first attempt and stops before
a retry delay would reach the limit, preserving the last error. Set `timeout: nil`
in the retry policy to remove that budget. Zero initial backoff or a zero cap
disables backoff; Retry-After remains effective unless explicitly disabled.


## Pristine 0.3.0 status-range prerequisite

The Python SDK retries every HTTP status from 500 through 599. TypeSafeSDK
represents that rule with Pristine 0.3.0's provider-level
`status_retry_ranges` contract rather than enumerating one hundred integer
overrides or changing Pristine's global defaults. Exact caller-selected HTTP
statuses continue to use exact provider overrides, while the default full 5xx
set compacts to one `500..599` rule.

Per-call `RetryPolicy` values rebuild the provider profile used for that call,
so replacing `http_statuses` really changes classification rather than only
changing the backoff loop. `respect_retry_after: false` also clears Pristine's
classified retry delay for that call.
