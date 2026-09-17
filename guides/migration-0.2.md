# Migrating to 0.2.0

This is additive API work, not a switch from Pristine to another HTTP client.
The minimum runtime dependency stays Pristine ~> 0.3.1; Jason remains ~> 1.4.5.
Telemetry is now a direct dependency because the semantic API calls it directly.

| Existing code | 0.2.0 behavior / optional migration |
| --- | --- |
| `Noul.new(attrs)` | Still returns the legacy struct |
| `Choice.new(criteria, opts)` | Still returns the legacy struct |
| `Score.new(criteria, opts)` | Still returns the legacy struct |
| `system_one(client, state, map)` | Still wire-oriented, string answer IDs |
| `extra_body` on system_one | Still last-write-wins |
| `evaluate(client, state, questions)` | New strict API, map or pair list, restores caller IDs/options |
| `Question.*.new` / `new!` | New tuple / raising semantic constructors |
| `timeout` | Still seconds; do not reinterpret as milliseconds |
| `task_timeout_ms`, `attempt_timeout_ms` | New explicit batch millisecond budgets |

To adopt strict semantics, replace question constructors with top-level
`noul/choice/score`, call `evaluate`, and update answer access to the original
caller key type. Alternatively keep string question IDs to minimize call-site
changes. Strict preparation also accepts legacy structs, but rejects invalid
semantic counts/shapes that low-level parity previously sent to the server.

Known numeric probabilities/confidence now enforce [0,1] during wire decoding;
negative/noninteger usage and normalized key collisions fail rather than being
accepted/overwritten. Unknown answer tags still skip typed decoding and now
remain explicitly available in `unknown_answers` plus `raw`.

Existing answer/response structs have additive fields. Avoid whole-struct equality
against manually constructed minimal expected values; pattern-match fields you
actually assert. The response module has not been renamed, and no Result wrapper
or duplicate answer struct hierarchy is introduced. `TypeSafeSDK.Answer.*` and
`TypeSafeSDK.Response` are helper namespaces.

No silent retry-default change, automatic probability normalization, risk-tolerance
policy, new global supervisor, or guaranteed transport backpressure is introduced.
