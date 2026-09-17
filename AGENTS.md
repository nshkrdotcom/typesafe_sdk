# Repository Guidelines

## Architecture

- This is a standalone provider SDK, not an umbrella.
- Runtime HTTP semantics belong to `pristine`; do not introduce a second HTTP stack.
- `lib/typesafe_sdk/generated/**` is generator-owned. Put custom behavior in handwritten modules outside that tree.
- `codegen/**` is build/maintenance tooling and is compiled only in dev/test.
- `priv/upstream/openapi.json` is the committed generation source. Refresh it intentionally and review diffs.


## Pristine prerequisite

- `pristine ~> 0.3.0` is a hard dependency.
- `PREREQUISITE_PRISTINE_0.3.0.md` must be completed in the Pristine repo before
  the final TypeSafe generator/runtime QC pass.
- Do not replace `status_retry_ranges: [%{range: 500..599, ...}]` with 100 exact
  status entries and do not downgrade the dependency to 0.2.x.
- `mix typesafe.prereq` is the executable capability gate.

## Dependency / Poncho behavior

Committed dependency tuples are ordinary Hex requirements. If
`MIX_WORKSPACE_OPS_BOOTSTRAP` is loaded, `mix.exs` delegates eligible dependency
source selection to that workspace bootstrap, matching the sibling SDK pattern.
Do not hardcode sibling paths into the repository.

## Runtime environment

Runtime modules under `lib/**` must not call `System.get_env/1` or related OS
environment APIs. Host configuration and `config/runtime.exs` are the environment
boundary. Tests and Mix maintenance tasks may read environment values where the
purpose explicitly requires it.

## Public parity

The supplied Python `typesafe-sdk` 0.6.0 repository is the initial semantic
oracle. Preserve:

- two operations: System One and model list
- Python question wire shapes and extra raw fields
- last-write-wins `extra_body`
- protected auth/accept/user-agent/SDK/runtime/retry headers
- unknown future answer types are ignored, not fatal
- score legend/probability JSON keys materialize as integers
- Python HTTP status/error message mapping
- client and per-call timeout/retry override semantics

Elixir should remain idiomatic: return `{:ok, value}` / `{:error, error}` and use
one client rather than separate sync/async class trees.

## Gates

Run in this order after generation:

1. Complete and QC `PREREQUISITE_PRISTINE_0.3.0.md` in Pristine.
2. `mix deps.get`
3. `mix typesafe.prereq`
4. `mix typesafe.refresh --project-root .` when validating live upstream parity
5. `mix typesafe.generate --project-root .`
6. `mix format --check-formatted`
7. `mix compile --warnings-as-errors`
8. `mix test`
9. `mix test --include live` with `TYPESAFE_API_KEY`
10. `mix credo --strict`
11. `mix dialyzer`
12. `mix docs --warnings-as-errors`
13. `mix typesafe.verify --project-root .`
14. `mix hex.build --unpack`

Do not call the handoff complete while any applicable gate is red.
