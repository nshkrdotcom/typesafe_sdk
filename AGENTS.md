# Repository Guidelines

## Architecture

- This is a standalone provider SDK, not an umbrella.
- Runtime HTTP semantics belong to `pristine`; do not introduce a second HTTP stack.
- `lib/typesafe_sdk/generated/**` is generator-owned. Put custom behavior in handwritten modules outside that tree.
- `codegen/**` is build/maintenance tooling and is compiled only in dev/test.
- `priv/upstream/openapi.json` is the committed generation source. Refresh it intentionally and review diffs.


## Pristine prerequisite

- `pristine ~> 0.4.0` is a hard dependency.
- The retained `PREREQUISITE_PRISTINE_0.3.0.md` records the earlier status-range prerequisite; Pristine 0.4 is now the runtime contract.
- Do not replace `status_retry_ranges: [%{range: 500..599, ...}]` with 100 exact status entries and do not downgrade the dependency.
- Cancellation tokens/capability discovery come directly from Pristine 0.4; do not add a TypeSafe transport cancellation engine.
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

For intentional upstream/codegen changes, run in this order after generation
(for ordinary changes use the non-regenerating `scripts/check_handoff.sh`):

1. `mix deps.get`
2. `mix typesafe.prereq`
3. `mix typesafe.refresh --project-root .` when validating live upstream parity
4. `mix typesafe.generate --project-root .` only for intentional upstream/codegen changes
5. `mix format --check-formatted`
6. `mix compile --warnings-as-errors`
7. `mix test`
8. `mix test --include live` with `TYPESAFE_API_KEY` when release policy requires it
9. `mix credo --strict`
10. `mix reach.check --arch --smells`
11. `mix dialyzer`
12. `mix docs --warnings-as-errors`
13. `mix typesafe.schema.verify`
14. `mix typesafe.verify --project-root .`
15. `mix hex.build --unpack`
16. `mix ci` as the final aggregate gate

Do not call the handoff complete while any applicable gate is red.

## 0.4.0 semantic/OTP layer and release discipline

- Read `docs/implementation/0.4.0/README.md`, the retained 0.3/0.2 records, and
  `HANDOFF.md` before changing the semantic surface. Keep public response/answer
  structs additive; `Response.values/1` is a projection, not another result model.
- Legacy constructors/system_one remain parity APIs. Strict Question.* / evaluate
  own semantic counts, protected extras, caller identity and relational validation.
- Never use `String.to_atom/1` on untrusted data. Ordered JSON and cached fragments
  must be built only from validated question definitions.
- Application fixtures must exercise the real Pristine serialization/retry/decode
  path. Do not use fixtures as evidence that a live API or transport bound works.
- Keep batch lifecycle isolated per enumeration; test timeout, early halt, caller
  death, unordered identity, and creators that trap exits.
- `TypeSafeSDK.OTP.Server` must remain opt-in: no package-global TaskSupervisor or
  second application runtime. Require a caller-owned TaskSupervisor and preserve
  explicit per-server `max_in_flight` bounds.
- OTP tags are opaque application state and must not enter automatic telemetry.
  OTP.Server scopes requests with private cancellation tokens; caller cancellation
  may be mirrored inward, but caller-owned tokens must never be mutated implicitly.
- Semantic telemetry never emits state/questions/bodies/headers/raw errors, answer
  labels/values, opaque tags, or stacktraces. Caller metadata stays nested and
  explicitly caller-controlled.
- Keep `.reach.exs` green. Do not weaken an architectural rule merely to hide a
  dependency inversion; generated modules/data structs are intentionally outside
  the small handwritten layer model.
- Run schema verification in addition to codegen verification. Do not regenerate
  before a freshness gate just to hide pre-existing drift. Only intentional source
  edits justify regeneration; review generated diffs.
- Release target is 0.4.0, dated 2026-09-17. Historical/dependency/upstream versions
  are not placeholders to globally replace. Do not assert publication or successful
  BEAM gates until they have actually run.
