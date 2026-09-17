#!/usr/bin/env bash
set -euo pipefail

mix deps.get
mix typesafe.prereq
mix typesafe.generate --project-root .
mix format --check-formatted
mix compile --warnings-as-errors
mix test
mix credo --strict
mix dialyzer
mix docs --warnings-as-errors
mix typesafe.verify --project-root .
mix hex.build --unpack
