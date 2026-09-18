#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="$(sed -n 's/^[[:space:]]*@version "\([^"]*\)".*/\1/p' mix.exs | head -n 1)"
if [[ -z "$VERSION" ]]; then
  echo "Could not determine package version from mix.exs" >&2
  exit 1
fi

PACKAGE_DIR="typesafe_sdk-${VERSION}"
LIVE_ROOT="tmp/release-qc/${VERSION}/live"

is_blank() {
  local value="$1"
  [[ -z "${value//[[:space:]]/}" ]]
}

usage() {
  cat <<'EOF'
Usage: bash scripts/release_qc.sh <command>

Commands:
  offline          Run the complete non-live checkout gate and final mix ci.
  package-dry-run  Rebuild/unpack the Hex artifact and run hex.publish --dry-run.
  live             Run resumable billable live release QC. Requires
                   TYPESAFE_RELEASE_LIVE=1 and TYPESAFE_API_KEY.
  live-reset       Delete only the resumable live-QC state under tmp/release-qc.
  github-ci        Require successful push-triggered CI for the current HEAD.

This script never publishes to Hex, creates a release, creates a tag, commits,
or pushes. Upstream refresh/regeneration also remain explicit maintainer actions.
EOF
}

require_bootstrap() {
  if [[ -z "${MIX_WORKSPACE_OPS_BOOTSTRAP:-}" || ! -f "${MIX_WORKSPACE_OPS_BOOTSTRAP}" ]]; then
    cat >&2 <<'EOF'
MIX_WORKSPACE_OPS_BOOTSTRAP must point to the maintenance-tool bootstrap for a
source checkout. Reproduce the pinned setup from .github/actions/setup/action.yml
(or the contributor section in README.md), then rerun this command.
EOF
    exit 1
  fi
}

run_offline() {
  require_bootstrap
  bash -n scripts/check_handoff.sh scripts/release_qc.sh examples/run_all.sh
  git diff --check
  bash scripts/check_handoff.sh
  mix ci
  git diff --check
}

run_package_dry_run() {
  require_bootstrap

  rm -rf "$PACKAGE_DIR"
  mix hex.build --unpack
  test -d "$PACKAGE_DIR"
  cp mix.lock "$PACKAGE_DIR/mix.lock"

  (
    cd "$PACKAGE_DIR"
    unset MIX_WORKSPACE_OPS_BOOTSTRAP
    unset GITHUB_WORKSPACE
    rm -rf _build deps
    mix deps.get
    mix hex.publish --dry-run --yes
  )

  echo "Hex package/docs dry run passed for ${PACKAGE_DIR}; nothing was published."
}

run_once() {
  local name="$1"
  shift

  local marker="${LIVE_ROOT}/${name}.done"
  local log="${LIVE_ROOT}/${name}.log"

  if [[ -f "$marker" ]]; then
    echo "SKIP ${name}: already passed in this live-QC state."
    return 0
  fi

  echo
  echo "===== LIVE QC: ${name} ====="
  "$@" 2>&1 | tee "$log"
  touch "$marker"
}

run_live() {
  require_bootstrap

  if [[ "${TYPESAFE_RELEASE_LIVE:-}" != "1" ]]; then
    cat >&2 <<'EOF'
Live release QC is billable and intentionally opt-in.
Set TYPESAFE_RELEASE_LIVE=1 only after offline/package gates are green and the
credential belongs to the selected endpoint.
EOF
    exit 1
  fi

  if [[ ! -v TYPESAFE_API_KEY ]] || is_blank "$TYPESAFE_API_KEY"; then
    echo "TYPESAFE_API_KEY is required for live release QC." >&2
    exit 1
  fi

  if [[ -v TYPESAFE_BASE_URL ]] && is_blank "$TYPESAFE_BASE_URL"; then
    echo "TYPESAFE_BASE_URL is set but blank; unset it or provide the selected API root." >&2
    exit 1
  fi

  if [[ -v TYPESAFE_DEFAULT_MODEL ]] && is_blank "$TYPESAFE_DEFAULT_MODEL"; then
    echo "TYPESAFE_DEFAULT_MODEL is set but blank; unset it or provide a model ID." >&2
    exit 1
  fi

  mkdir -p "$LIVE_ROOT"
  unset TYPESAFE_EXAMPLE_RETRY

  echo "Live endpoint: ${TYPESAFE_BASE_URL:-https://api.typesafe.ai}"
  echo "Live model:    ${TYPESAFE_DEFAULT_MODEL:-jev-latest}"
  echo "API key:       [set, not displayed]"
  echo "Retries:       disabled"
  echo "State:         ${LIVE_ROOT}"
  echo
  echo "Successful steps are marked under tmp/ and skipped on resume."
  echo "The default full live release path is bounded to 67 HTTP requests:"
  echo "63 for the complete example/evaluation runner + 2 live tests + 2 recorder calls."

  run_once live-tests \
    mix test --include live --warnings-as-errors

  run_once recorder \
    mix typesafe.record \
      --output "${LIVE_ROOT}/capture" \
      --baseline test/fixtures/live

  run_once live-evaluation \
    mix run examples/live_evaluation.exs
  run_once live-semantic \
    mix run examples/live_semantic.exs
  run_once live-composition-contracts \
    mix run examples/live_composition_contracts.exs
  run_once live-runtime-controls \
    mix run examples/live_runtime_controls.exs
  run_once live-batching \
    mix run examples/live_batching.exs
  run_once live-observability \
    mix run examples/live_observability.exs
  run_once live-decision-patterns \
    mix run examples/live_decision_patterns.exs
  run_once live-otp-server \
    mix run examples/live_otp_server.exs
  run_once live-recursive-decisions \
    mix run examples/live_recursive_decisions.exs

  run_once evaluation-development \
    mix run examples/evaluation/run.exs -- \
      --split development \
      --sweep \
      --max-auto-error 0.05 \
      --output "${LIVE_ROOT}/development.json"

  run_once evaluation-held-out \
    mix run examples/evaluation/run.exs -- \
      --split held-out \
      --policy "${LIVE_ROOT}/development.policy.json" \
      --output "${LIVE_ROOT}/held-out.json"

  echo
  echo "All live release-QC steps passed. State retained at ${LIVE_ROOT}."
}

reset_live() {
  rm -rf "$LIVE_ROOT"
  echo "Removed ${LIVE_ROOT}. The next live run will execute and bill every step again."
}

run_github_ci() {
  command -v gh >/dev/null 2>&1 || {
    echo "gh is required for the github-ci gate." >&2
    exit 1
  }

  if [[ -n "$(git status --porcelain)" ]]; then
    echo "github-ci requires a clean worktree for an exact commit check." >&2
    exit 1
  fi

  local repo head run_id run_sha run_event conclusion
  repo="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
  head="$(git rev-parse HEAD)"

  echo "Repository: ${repo}"
  echo "HEAD:       ${head}"

  run_id=""
  for _ in $(seq 1 30); do
    run_id="$(
      gh run list \
        --workflow ci.yml \
        --commit "$head" \
        --event push \
        --limit 10 \
        --json databaseId \
        --jq '.[0].databaseId // empty'
    )"
    [[ -n "$run_id" ]] && break
    sleep 2
  done

  if [[ -z "$run_id" ]]; then
    echo "No push-triggered CI run found for ${head}. Push this exact commit, then rerun." >&2
    exit 1
  fi

  run_sha="$(gh run view "$run_id" --json headSha --jq '.headSha')"
  run_event="$(gh run view "$run_id" --json event --jq '.event')"
  [[ "$run_sha" == "$head" ]]
  [[ "$run_event" == "push" ]]

  gh run watch "$run_id" --exit-status

  conclusion="$(gh run view "$run_id" --json conclusion --jq '.conclusion')"
  [[ "$conclusion" == "success" ]]

  echo "GitHub CI passed for exact HEAD ${head} (run ${run_id})."
}

case "${1:-}" in
  offline) run_offline ;;
  package-dry-run) run_package_dry_run ;;
  live) run_live ;;
  live-reset) reset_live ;;
  github-ci) run_github_ci ;;
  -h|--help|help|"") usage ;;
  *)
    usage >&2
    exit 2
    ;;
esac
