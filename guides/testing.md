# Application Testing Through the Real SDK

`TypeSafeSDK.Test` injects a scripted implementation of `Pristine.Ports.Transport`.
It does not bypass generated request construction, JSON serialization, auth/header
handling, retry classification, response decoding or semantic validation.
There is no live-network fallback and callers cannot replace its transport via
`Test.client` options. Use synthetic inputs and test keys only.

```elixir
client = TypeSafeSDK.Test.client()
client = TypeSafeSDK.Test.stub(client, [
  team: {:choice, :billing,
    probabilities: %{billing: 0.52, technical: 0.48}, confidence: 0.23},
  urgent: {:noul, 0.9},
  severity: {:score, 0.7, probabilities: %{0 => 0.3, 1 => 0.7}, confidence: 0.8}
], model: "jev-fixture", usage: %{input_tokens: 14, output_tokens: 7},
   request_id: "req-triage")
# Run your ordinary application code with this client.
TypeSafeSDK.Test.verify!(client)
TypeSafeSDK.Test.close(client)
```

Convenient specs include `{:choice, option, confidence}` and
`{:score, value, confidence}`. Choice synthesis assigns the supplied probability
to the selected option and distributes the remainder uniformly; the same value
is its synthetic confidence. Score synthesis splits mass between adjacent levels
so its expectation matches the supplied score. Exact specs keep distribution and
confidence independent. Exact distributions must sum to 1 within 1e-9.

The actual serialized request determines IDs, types, Choice options and Score
ranges. Missing/extra stub IDs, wrong types, invalid selections, bad distribution
domains and invalid score ranges fail loudly. Contract failures are also recorded
in scenario state, so `verify!` fails even if a runtime normalizes the transport
exception into an error result.

## Failures and finite sequences

```elixir
client = TypeSafeSDK.Test.client(
  retry: [max_retries: 2, backoff_initial: 0, backoff_jitter: 0])
client = TypeSafeSDK.Test.stub_sequence(client, [
  {:http_error, 529},
  {:transport_error, :timeout},
  {:answers, [urgent: {:noul, 0.95}], [request_id: "req-after-retries"]}
])
```

Each retry consumes another fixture. Exhaustion and unused entries fail
verification. Default test clients disable retries; opt in explicitly when
checking production retry behavior. `stub_http_error(client, 429,
retry_after_ms: 1200)`, `stub_transport_error(client, :timeout)` and
`stub_models(client, [%{name: "jev-test", description: "Fixture",
release_date: "2026-09-16"}])` cover other paths. Raw `stub_response` is an
intentional escape hatch for malformed/future wire-response tests.

`stub_callback(client, fn request -> fixture end)` builds a fixture from the
actual request and supports synchronized concurrency tests. Return an ordinary
sequence-entry fixture, not an already-decoded semantic response.

## Ownership and inspection

Scenario state is private to each explicit client, shared with child tasks only
when you pass that client. The creator is monitored; normal or abnormal creator
exit closes the scenario. Call `verify!` BEFORE that owner exits, not from an
ExUnit `on_exit` callback running afterward. `close` is idempotent. `requests`
returns actual captured requests; `stats` includes total, dropped history,
pending sequence entries and failures. History defaults to the last 1000
requests; `history_limit` accepts 1..10000. Fixtures and tests are not evidence
of live service correctness or performance.
