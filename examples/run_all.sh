#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

is_blank() {
  local value="$1"
  [[ -z "${value//[[:space:]]/}" ]]
}

if [[ ! -v TYPESAFE_API_KEY ]] || is_blank "$TYPESAFE_API_KEY"; then
  echo "Set a non-blank TYPESAFE_API_KEY for the selected endpoint; live calls may incur charges." >&2
  exit 2
fi

if [[ -v TYPESAFE_BASE_URL ]] && is_blank "$TYPESAFE_BASE_URL"; then
  echo "TYPESAFE_BASE_URL is set but blank; unset it or provide the TypeSafe-compatible API root." >&2
  exit 2
fi

if [[ -v TYPESAFE_DEFAULT_MODEL ]] && is_blank "$TYPESAFE_DEFAULT_MODEL"; then
  echo "TYPESAFE_DEFAULT_MODEL is set but blank; unset it or provide a model ID for the selected provider." >&2
  exit 2
fi

if [[ "${TYPESAFE_EXAMPLE_RETRY:-0}" == "1" ]]; then
  echo "Retry opt-in enabled: live_runtime_controls.exs may make one additional bounded call." >&2
fi

mix run examples/live_evaluation.exs
mix run examples/live_semantic.exs
mix run examples/live_composition_contracts.exs
mix run examples/live_runtime_controls.exs
mix run examples/live_batching.exs
mix run examples/live_observability.exs
mix run examples/live_decision_patterns.exs
mix run examples/live_otp_server.exs
mix run examples/live_recursive_decisions.exs
mix run examples/evaluation/run.exs -- --split development --sweep \
  --max-auto-error 0.05 --output tmp/examples/development.json
mix run examples/evaluation/run.exs -- --split held-out \
  --policy tmp/examples/development.policy.json --output tmp/examples/held-out.json
