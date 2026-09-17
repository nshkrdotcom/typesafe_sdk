# Batching and Lifecycle

```elixir
prepared = TypeSafeSDK.prepare!(urgent: TypeSafeSDK.noul("Urgent?"))
results = TypeSafeSDK.evaluate_many(client, states, prepared,
  max_concurrency: 8, ordered: true, on_error: :collect,
  task_timeout_ms: 40_000, attempt_timeout_ms: 5_000)
```

`evaluate_many` collects a lazy `evaluate_stream`. Input can be any Enumerable.
Shared questions/options are validated before work starts and invalid shared
configuration raises even under `:collect`. Individual state validation/API
failures return one error in the result stream. Prepared is reused, not rebuilt
for each state. Calling `evaluate_stream` alone performs no HTTP and starts no
supervisor; every enumeration has independent lifecycle state.

| Option | Contract |
| --- | --- |
| `max_concurrency` | 1..1024; default 8; local batch limit, not a service quota |
| `max_pending` | Ordered prefetch/window bound; defaults to 4 x concurrency; concurrency..10000 |
| `ordered` | true by default; false emits completion order |
| `on_error` | `:collect` or `:raise`; default collect |
| `task_timeout_ms` | Positive integer; default 40000; bounds the whole worker |
| `attempt_timeout_ms` | Positive integer; passed as runtime `timeout_ms` |

Do not combine `attempt_timeout_ms` with `timeout` or `timeout_ms`. Ordinary
request `timeout` remains seconds. Retry budget/backoff remain seconds in
RetryPolicy. Set the task budget to accommodate your intended retry budget;
a task timeout can terminate a request before retry exhaustion.

```elixir
TypeSafeSDK.evaluate_stream(client, large_enumerable, prepared, ordered: false)
|> Enum.each(fn
  {:ok, response} -> IO.inspect({response.batch_index, response.answers})
  {:error, error} -> IO.inspect({error.details.batch_index, error.type})
end)
```

Batch indexes are zero-based and exist on errors too. Do not zip unordered
results positionally with inputs. `on_error: :raise` stops enumeration at the
first observed failure. Unlinked tasks isolate exits from the consumer; task
exits become sanitized `:task_exit` errors, timeouts become `:timeout` with
`details.scope == :batch`. Raw exit reasons can contain state and are omitted.

An owned supervisor and stream continuation shut down outstanding tasks on
early halt, exceptions and caller termination. Ordered execution prefetches at
most `max_pending` inputs into a finite window. All results from that window are
delivered before the next window begins. This bounds completed-result buffering
behind a slow predecessor as well as input prefetch. The tradeoff is a window
boundary: some workers can be idle while a window's final slow request finishes.
Tune `max_pending` to balance bounded buffering against that utilization cost.
Unordered execution has no window boundary and uses the normal demand-driven
OTP task stream. These bounds count values, not bytes.

Early halt may discard prefetched inputs; do not use a destructive/acknowledging
source unless the application explicitly owns its reprocessing semantics.
Collecting all results necessarily uses memory proportional to output size; use
streaming for large inputs. Escaping worker exceptions are normalized before
OTP's Task crash reporter can print their state-bearing arguments or reasons.

This does NOT establish a global transport queue bound, peer stream limit, or
streaming response-byte cap. Nor does killing a worker prove the remote server
stopped processing it. See [runtime guarantees](runtime-capabilities.md) and
[retry ambiguity](errors-and-retries.md).
