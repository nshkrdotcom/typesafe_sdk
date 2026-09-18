# Evaluating Model Judgments and Application Decisions

The runnable [support-triage example](../examples/evaluation/README.md) loads
synthetic development and held-out JSONL datasets, runs real SDK evaluations,
and reports model and policy metrics separately. It is an implementation-quality
workflow example, not a claim of benchmark performance or calibrated thresholds.

```bash
export TYPESAFE_API_KEY="provider-key"
export TYPESAFE_BASE_URL="https://your-typesafe-host.example/deployment"
export TYPESAFE_DEFAULT_MODEL="provider-model-id"

mix run examples/evaluation/run.exs -- --split development --sweep \
  --max-auto-error 0.05 --output tmp/triage-development.json
mix run examples/evaluation/run.exs -- --split held-out \
  --policy tmp/triage-development.policy.json --output tmp/triage-held-out.json
```

Each row causes a real evaluation. `--base-url` / `--model` override the matching
environment values. The base URL is the TypeSafe API root before `/v1/models` and
`/v1/systemone`; use a key and model issued for that selected provider. A generic
OpenAI-compatible endpoint is not sufficient unless it also implements this
TypeSafe contract. A sweep reuses the same predictions; it does not call the API
for every threshold.
Development selection maximizes automatic coverage subject to the explicitly
chosen automatic-error constraint, breaking ties deterministically. A policy is
frozen with its observed model version when exactly one model version was seen.
Held-out execution requires that policy file, forbids sweeps and threshold
arguments, and uses the frozen model. No automatic policy is selected when no
candidate with automatic decisions satisfies the constraint.

A label can list multiple acceptable departments/routes for genuinely ambiguous
examples. Labels never invent an exact "correct probability." Keep raw predicted
distributions, IDs, model versions and request IDs for analysis, but do not write
state or API keys into reports. Separate operational failures from model mistakes.

Metrics include model accuracy, routing-policy accuracy, end-to-end routing
accuracy, automatic coverage/error, human review counts and required-human
recall, failures, token usage and nearest-rank p50/p95 latency. Undefined rates
are null. Model/policy accuracy use successful rows; end-to-end accuracy and
coverage use all rows. Conditional automatic error uses automatic decisions only.
Latency includes every row for which elapsed time was actually observed; the
report gives that observation count. Missing token values yield unknown totals,
not invented zeros. See the example README for the exact denominator rules.

Do not tune thresholds after inspecting held-out results and still describe that
set as held out. Build sufficiently large, representative, independently labeled
data and uncertainty estimates before making deployment claims. The tiny bundled
synthetic datasets demonstrate plumbing, not statistical reliability.