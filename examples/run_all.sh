#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${TYPESAFE_API_KEY:?Set TYPESAFE_API_KEY; these examples call the live API and may incur charges}"

mix run examples/live_evaluation.exs
mix run examples/live_semantic.exs
mix run examples/live_batching.exs
mix run examples/live_observability.exs
mix run examples/live_decision_patterns.exs
mix run examples/live_recursive_decisions.exs
mix run examples/evaluation/run.exs -- --split development --sweep \
  --max-auto-error 0.05 --output tmp/examples/development.json
mix run examples/evaluation/run.exs -- --split held-out \
  --policy tmp/examples/development.policy.json --output tmp/examples/held-out.json
