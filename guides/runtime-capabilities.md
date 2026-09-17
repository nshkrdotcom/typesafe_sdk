# Runtime Bounds and Capability Audit

The SDK intentionally does not add a second pool, mailbox queue, HTTP engine or
retry engine. Hfiguera's useful overload/body-size/cancellation concerns become
explicit requirements at the Pristine transport boundary.

```elixir
report = TypeSafeSDK.RuntimeCapabilities.report(client)
TypeSafeSDK.RuntimeCapabilities.check(client, [:bounded_queue, :max_response_bytes])
```

```bash
mix typesafe.capabilities
mix typesafe.capabilities --require bounded_queue,max_response_bytes,cancellation_cleanup
```

The supplied source does not establish these capabilities for the default
Pristine Finch adapter. They report **unverified** and required guarantees fail
closed. This is not a statement that Pristine lacks every capability; it is a
statement that this SDK has no supported evidence to promise them.

A Pristine adapter can expose `typesafe_capabilities(transport_opts)` (preferred,
so its actual settings are inspected) or `typesafe_capabilities/0`:

```elixir
%{
  bounded_outstanding_requests: 16,
  bounded_queue: 32,
  max_response_bytes: 8_388_608,
  deterministic_overload: true,
  cancellation_cleanup: true
}
```

Positive numeric bounds are required; queue zero is valid. Boolean capabilities
must be exactly true. Missing/malformed/broken advertisements remain unverified.
`runtime_requirements: [...]` on `new_client` enforces the same check. The report
labels accepted values **advertised**, not verified: transport contract tests
must exercise saturation, bounded buffering during transfer, overload outcomes,
caller death and resource release. Do not add an adapter advertisement without
implementing and testing its guarantees in the owning runtime repository.

The SDK does implement per-enumeration batch task bounds and task cleanup.
A post-download byte-length check would not prevent an unbounded transfer, so
0.2.0 does not pretend such a check is a streaming response cap. Unresolved
runtime guarantees remain explicit release/deployment review items in HANDOFF.

Run `mix run examples/live_observability.exs` for a complete live walkthrough.
See [the live example catalog](../examples/README.md) for setup and API-call costs.
