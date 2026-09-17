# Live examples for TypeSafeSDK 0.4.0

Every runnable example calls the real TypeSafe endpoint at
`https://api.typesafe.ai`. There is no offline mode, fixture transport, synthetic
response or fallback. Inputs and evaluation labels are illustrative synthetic
support data; outputs come from the service. Calls may incur charges.

## Setup and run everything

Run from the repository root using `.tool-versions`. For a source checkout,
configure the pinned maintenance-tool bootstrap described in the main README;
then run `mix deps.get`. Supply your real API key through the environment:

```bash
read -rsp "TypeSafe API key: " TYPESAFE_API_KEY
echo
export TYPESAFE_API_KEY
bash examples/run_all.sh
```

The runner stops on failure. It runs the six standalone scripts below, then
12 development and eight held-out evaluations. Expect approximately 37–38
requests, including model lists and work prefetched before early halt; this is
not a billing guarantee. Automatic retries are disabled for these examples.
Missing credentials, failed requests and unmet evaluation-policy criteria return
a nonzero exit status. Do not repeatedly rerun a failed command without checking
its output: an ambiguous failure may already have been processed upstream.

The shared `support/live.exs` selects the live base URL and Finch transport
explicitly, disables automatic replay, and uses a 15-second request timeout.
`TYPESAFE_DEFAULT_MODEL` selects the model for standalone scripts (default
`jev-latest`); the evaluation CLI uses `--model` and freezes the observed version
for held-out runs. A configured test transport or alternate base URL cannot
silently redirect these examples. No API key is printed. Output includes live
answers and synthetic inputs; use care if substituting private data.

## Choose an example

| Command | What it demonstrates |
| --- | --- |
| `mix run examples/live_evaluation.exs` | Model list; retained `Noul`, `Choice`, `Score` constructors; wire-oriented `system_one!`; string answer keys, distributions and usage |
| `mix run examples/live_semantic.exs` | Tuple and raising strict constructors; structured descriptions and labeled Score levels; finite atom/string identity; validation and prepared reuse; `evaluate`; response fetch/filter/raw access; all uncertainty helpers and explicit gates |
| `mix run examples/live_batching.exs` | `evaluate_many`; lazy `evaluate_stream`; bounded concurrency and ordered windows; unordered `batch_index`; collect/raise policies; task/attempt budgets; early halt |
| `mix run examples/live_observability.exs` | Live `evaluate!`; named telemetry handler attach/detach; nested caller metadata; native duration conversion; extra headers; response metadata; real-adapter capability report and fail-closed check; schema freshness |
| `mix run examples/live_decision_patterns.exs` | Weighted normalized Score composition; explicit Noul threshold and confidence gate; supervised speculative live model lookup and cleanup |
| `mix run examples/live_recursive_decisions.exs` | Two-level hierarchical decision descent using caller-key restoration and the primary-value projection; explicit reminder that production recursion needs bounds |
| `mix run examples/evaluation/run.exs -- ...` | Labeled development/held-out workflow, model versus policy metrics, threshold sweep, frozen model/policy, coverage/error/latency/token reporting |

`support/live.exs` and `evaluation/evaluation.exs` are supporting modules, not
standalone entrypoints. See [the evaluation README](evaluation/README.md) for
complete CLI commands, dataset contracts and metric definitions.

## Reading results and handling failures

The semantic script makes two calls using one prepared question set. It mixes
atom and string question/Choice keys deliberately: fetch answers using the exact
original key. A Score's rounded expected level can differ from its modal level;
Choice margin is not provider confidence. `gate` classifies certainty under
explicit thresholds and never executes a business action. A confident Noul
false is still false: check `yes?` separately. Thresholds and weights are
illustrative, not calibrated deployment recommendations.

The batching script makes three ordered and three unordered calls, then takes
one result from a new stream. Unordered output must be joined using `batch_index`,
not zipped positionally to inputs. `:collect` returns errors as values; the script
inspects them and exits nonzero rather than treating failures as success.
`:raise` raises at the first observed failure. Edit `task_timeout_ms` or
`attempt_timeout_ms` to explore deadline failures; live latency cannot guarantee
which request will time out. No mocked timeout or failure is injected.
Early halt stops owned local tasks, but already-submitted work may still run and
be billed remotely. It does not prove physical transport cancellation.

The telemetry handler prints only SDK semantic event data and the explicit
caller metadata chosen by this example. It converts native monotonic duration
to milliseconds and detaches in `after`, including on failure. The capability
check's error is expected for unadvertised runtime bounds; it is displayed rather
than mistaken for evidence of a broken live API or guaranteed transport limits.

The shared failure handler displays the error category, status, path, request ID,
Retry-After advice and default-policy retryability before raising. Retryability
is not remaining retry budget or permission to repeat an ambiguous request.
The examples do not deliberately force upstream HTTP errors, retry sequences,
unknown future answers or overload conditions. Those are nondeterministic live
outcomes; deterministic coverage belongs in the test suite.

## Testing APIs and local maintenance

`TypeSafeSDK.Test` is intentionally a fixture API, so it is documented in the
[application testing guide](../guides/testing.md) and exercised in ExUnit, not
used by any runnable example here. Likewise, local invalid-input checks and
schema tasks alone do not establish a live integration. Protected extras,
validation paths, unknown future types, and migration details are covered in
[semantic questions](../guides/semantic-questions.md),
[answers](../guides/answers-and-confidence.md), and
[migration](../guides/migration-0.2.md).

To capture actual responses for explicit review after running the examples:

```bash
mix typesafe.record --output tmp/live --baseline test/fixtures/live
```

Reports from the all-examples runner go to `tmp/examples/`; captures go to
`tmp/live/`. These directories are ignored. No example commits a baseline,
publishes a package or claims that synthetic evaluation data proves production
accuracy. All example sources and datasets are included in the Hex package.


0.4.0 adds per-answer telemetry and bounded OTP integration; runtime-control examples are documented in `guides/runtime-controls.md`; live examples remain opt-in and may incur API charges.
