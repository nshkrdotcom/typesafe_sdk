# Support-triage evaluation workflow

This runnable example measures narrow model judgments separately from application
routing policy. It uses `TypeSafeSDK.evaluate_many`, the normal Pristine path,
and the public semantic questions/answers. The CLI uses the same configurable live
endpoint/model selection as the standalone examples and always executes through the
normal SDK/Pristine HTTP path; no mocked backend or offline fallback is used.
Automatic retries are disabled.

## Endpoint and model selection

Use credentials and model IDs issued by the endpoint you select:

```bash
export TYPESAFE_API_KEY="provider-key"
export TYPESAFE_BASE_URL="https://your-typesafe-host.example/deployment"
export TYPESAFE_DEFAULT_MODEL="provider-model-id"
```

`TYPESAFE_BASE_URL` is the API root before the generated `/v1/models` and
`/v1/systemone` paths; a path prefix such as `/deployment` is retained. The host
must implement the TypeSafe operation/response contract and compatible bearer
authentication. An arbitrary OpenAI-compatible endpoint is not automatically a
TypeSafe-compatible endpoint.

CLI `--base-url` and `--model` values win over the matching environment defaults.
An explicit blank/invalid endpoint fails rather than silently contacting the
default provider. Run `mix run examples/evaluation/run.exs -- --help` for the full
option list.

## Data and commands

`datasets/development.jsonl` has 12 synthetic examples and
`datasets/held-out.jsonl` has 8 different synthetic examples. IDs and split markers
are validated; both department and route labels can contain multiple acceptable
answers. Replace these tiny illustrative sets with independently labeled,
representative data before drawing conclusions. No measured results are bundled.

```bash
# Set TYPESAFE_API_KEY in your shell before running; calls may incur charges.
mix run examples/evaluation/run.exs -- --split development --sweep \
  --max-auto-error 0.05 --output tmp/triage-development.json
mix run examples/evaluation/run.exs -- --split held-out \
  --policy tmp/triage-development.policy.json --output tmp/triage-held-out.json
```

Use `--dataset path.jsonl` for your own data with matching split markers. Other
options: `--base-url`, `--model`, `--max-concurrency`, and development-only `--confidence` /
`--urgency`. Thresholds are application policy, not SDK defaults. Development
without a sweep uses illustrative 0.8 confidence / 0.85 urgency values. With a
sweep, existing predictions are reused across the grid; no extra API requests
are made. An all-failure run cannot produce a valid selected policy. The CLI
returns nonzero when individual evaluations fail, retaining the report when one
has been produced.

The policy sends urgent cases to `urgent` first, then uncertain department
judgments to `review`, otherwise to the chosen department. Only department routes
count as automatic; `review` and `urgent` are human-handled routes. A frozen policy
pins the actual observed model when all successful development responses name
one version. Held-out runs require the policy and forbid overriding thresholds
or the frozen model. Inspect observed models; aliases can change upstream.

## Metrics and denominators

Model accuracy = selected department accepted / successful evaluations.
Policy accuracy = final route accepted / successful evaluations.
End-to-end policy accuracy = accepted final routes / all input rows.
Automatic coverage = automatic department routes / all rows.
Automatic error rate = unacceptable automatic routes / automatic routes.
Human rate = review or urgent routes / all rows.
Required-human recall = human-routed cases / rows whose acceptable routes are
exclusively human routes. Request failures stay in the all-row denominators.
Undefined rates are null, not zero or one. Counts accompany every policy metric.

Latency p50/p95 uses nearest-rank observed per-evaluation elapsed milliseconds,
including error elapsed times when available; unobserved task-kill durations are
not fabricated. Token totals are unknown if any successful response omits a
count. Token cost of failed/ambiguous attempts is not observable from the final
response and is not invented. Reports retain probabilities, labels, IDs, model
versions and request IDs, but omit state, headers and credentials.

`evaluation.exs` contains the loader, questions, recording, policy, metrics and
sweep implementation. Unit and transport-integrated example tests live in
`test/typesafe_sdk/evaluation_example_test.exs`. Those tests validate the harness;
they are not model-performance evidence. Broader deployment evaluation should
include confidence intervals, representative failure costs and independent label
review appropriate to the application.

## Failed policy selection and incomplete runs

If no swept development policy meets `--max-auto-error`, the script still writes
the captured predictions and complete sweep, with `selection_error`, no selected
policy and no invented fallback thresholds. It exits nonzero. Frozen policy files
are written only after an all-successful development run with one observed model
version. Held-out reports flag a model-version mismatch and exit nonzero rather
than presenting it as a comparable frozen-policy result.

## Run with the other live examples

`bash examples/run_all.sh` runs this workflow after the focused live feature,
OTP, observability and recursive-pattern scripts, writing reports to `tmp/examples/`.
See [the catalog](../README.md). The CLI is `run.exs`; `evaluation.exs` is its
supporting implementation and is not a standalone example. All requests use
actual service responses. Fixture-based harness regression tests remain in
`test/`, separate from the live example commands.