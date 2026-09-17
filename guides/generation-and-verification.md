# Generation And Verification

> **Prerequisite:** complete `PREREQUISITE_PRISTINE_0.3.0.md` first. This repo
> requires `pristine ~> 0.3.0` and intentionally uses its
> `status_retry_ranges` provider contract. Do not run the final generator/QC
> pass against Pristine 0.2.x.

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
