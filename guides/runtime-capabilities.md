# Runtime Bounds and Capability Audit

TypeSafe SDK does not add a second pool, mailbox queue, HTTP engine, retry engine
or transport cancellation implementation. Runtime capability discovery delegates
to `Pristine.RuntimeCapabilities.transport/1` and fails closed.

```elixir
report = TypeSafeSDK.RuntimeCapabilities.report(client)
report.runtime.unary_cancellation
# => %{status: :supported} | %{status: :unsupported} | %{status: :unverified}

TypeSafeSDK.RuntimeCapabilities.check(client, [
  :unary_cancellation,
  :cancellation_cleanup
])
```

```bash
mix typesafe.capabilities
mix typesafe.capabilities --require unary_cancellation,cancellation_cleanup
```

Pristine 0.4.0's built-in Finch-named unary adapter advertises verified
`:unary_cancellation` and `:cancellation_cleanup`; its cancellation path is
Execution Plane-backed and terminates the local unary operation before cleanup
returns. Third-party transports are normalized by Pristine and missing,
malformed or failing advertisements remain `:unverified`.

TypeSafe never infers support from an adapter module name, `function_exported?/3`
or transport options. The TypeSafe-facing report contains only the adapter name,
normalized capability statuses/values, and SDK batch-bound descriptions; it does
not expose credentials, headers or transport context options. Existing 0.2 bound
audit names remain present and report `%{status: :unverified}` when Pristine has
no verified/advertised value for them.

Custom Pristine capabilities such as `bounded_queue` or `max_response_bytes` may
also appear when an owning adapter advertises them through Pristine. Required
capabilities must have normalized status `:supported`. `runtime_requirements:` on
`new_client/1` enforces the same check.

The SDK itself implements per-enumeration batch task bounds and lifecycle cleanup.
A serialized **request** byte budget in 0.3 is a local pre-egress semantic control;
it is not a streaming response-body cap or a global transport queue guarantee.
See [runtime controls](runtime-controls.md) and [batching](batching.md).
