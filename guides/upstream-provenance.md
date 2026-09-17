# Upstream provenance

The initial semantic reference is the supplied Python `typesafe-sdk` 0.6.0
repository. The committed OpenAPI document was refreshed from
`https://api.typesafe.ai/openapi.json` on 2026-09-16, replacing the reconstructed
snapshot. The public operation surface remains:

- `POST /v1/systemone`
- `GET /v1/models`

Reviewed differences from the reconstructed Python wire snapshot:

- Upstream now names the `Question` and `Answer` discriminated unions. The source
  plugin expands those reviewed aliases into their three known alternatives.
- `Usage` now requires `input_tokens` and `output_tokens`, and no longer declares
  `billing_units`. The public Elixir type remains compatible with Python's public
  token-count type.
- Upstream provides richer field descriptions, examples, and validation constraints.
  The live API requires at least two score levels. Local normalization retains
  Python 0.6.0's nonempty-score check and leaves stricter server validation to the API.

The live model-list and System One tests exercise the real service. Unknown future
answer types are ignored, and raw question fields are preserved, independently of
the stricter generated wire schemas. Newly referenced schema names or changed
union alternatives require source review before generation.

Official documentation starts at [the documentation index](https://docs.typesafe.ai/llms.txt).
