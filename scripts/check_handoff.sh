#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

mix deps.get
mix typesafe.prereq
mix format --check-formatted
mix compile --warnings-as-errors
mix test --warnings-as-errors
mix credo --strict
mix dialyzer
mix docs --warnings-as-errors
mix typesafe.schema.verify
mix typesafe.verify --project-root .
mix hex.build --unpack

# No implicit refresh, regeneration, network evaluation, publication, or commit.
# Run intentionally after reviewing the offline results:
# mix typesafe.record --output tmp/live
