# Upstream input

`openapi.json` was fetched from `https://api.typesafe.ai/openapi.json` on
2026-09-16 and reviewed against the supplied Python SDK 0.6.0 public surface.
It replaces the initial reconstructed snapshot. The live schema adds named
`Question`/`Answer` unions and removes `Usage.billing_units`; see
`guides/upstream-provenance.md` for the reviewed differences.

To update intentionally:

```bash
mix typesafe.refresh --project-root .
mix typesafe.generate --project-root .
mix typesafe.verify --project-root .
```

Review upstream and generated diffs together. Refresh uses verified HTTPS.
