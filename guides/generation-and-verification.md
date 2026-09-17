# Generation And Verification

The SDK requires `pristine ~> 0.4.0`. The prerequisite command checks the retained
provider status-range contract plus Pristine 0.4 cancellation/capability behavior
before generation; TypeSafe does not implement transport cancellation itself.

Generation is a source-checkout maintenance task. Pristine Codegen and Provider
Testkit are checkout-only dependencies selected through the workspace bootstrap;
they are not needed to install or use the published SDK. On the development
workstation, use `~/.local/bin/typesafe-mix` in place of `mix` to select the local
tooling packages. Normal dependency tuples default to Hex.

CI checks out Pristine at a pinned commit and uses the same bootstrap hook for
Codegen and Provider Testkit only. The SDK runtime and its dependencies resolve
from Hex. This lets CI maintain the SDK before the tooling packages are published.

Generated artifacts are committed source, following the sibling SDK convention.

```bash
mix typesafe.prereq
mix typesafe.ir --project-root .
mix typesafe.generate --project-root .
mix typesafe.verify --project-root .
```

The provider and bounded OpenAPI source plugin live in
`codegen/typesafe_sdk/codegen/`. Inputs live under `priv/upstream/`;
canonical generated modules live under `lib/typesafe_sdk/generated/`; compiler
manifests live under `priv/generated/`.

To refresh from TypeSafe itself:

```bash
mix typesafe.refresh --project-root .
```

The refresh path validates that the two expected operations and reviewed schema
names still exist before replacing the committed OpenAPI document. New referenced
schema names require an explicit source-code mapping so remote schema input cannot
create arbitrary atoms during code generation.

## Verification

`mix test` runs offline tests by default. With `TYPESAFE_API_KEY` set, run
`mix test --only live` to exercise both real operations. To inspect their output,
run the [live example](../examples/README.md).

After generation, run formatting, compilation with warnings as errors, tests,
Credo, Dialyzer, docs with warnings as errors, and generated-file verification before
building a package. Review upstream changes intentionally; a documentation-only
release does not require refreshing the API snapshot.

## 0.2.0 schema, compatibility and live capture gates

Run `mix typesafe.schema.verify` alongside generated-code verification. To
intentionally update exports after an upstream source change, run
`mix typesafe.schema.export`; neither verification task refreshes or approves
new source automatically. `scripts/check_handoff.sh` executes the offline QC
sequence without first regenerating files (which could hide stale artifacts).

CI targets Elixir/OTP 1.18.4/27.3, 1.19.5/28.3.1 and 1.20.4/29.0.6. These are
configured compatibility targets, not a substitute for green matrix results.
`mix typesafe.record` makes two real synthetic-input calls, saves raw response
bodies and metadata, and produces diffs against `test/fixtures/live`. No real
recordings are bundled until a credentialed run has been reviewed. The scheduled
workflow requires repository variable TYPESAFE_LIVE_ENABLED=true and secret
TYPESAFE_API_KEY. It never runs on pull requests, silently fabricates fixtures,
or commits changes. Probability differences require interpretation, not blanket
byte-for-byte stability claims.
