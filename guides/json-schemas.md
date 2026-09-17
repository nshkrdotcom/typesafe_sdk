# JSON Schema Export and Freshness

```bash
mix typesafe.schema.export
mix typesafe.schema.export --output schemas/typesafe
mix typesafe.schema.verify
mix typesafe.schema.verify --output schemas/typesafe
```

The exports in `priv/json_schema` are `system-one-request.json`,
`system-one-response.json`, and `models-response.json`. They derive from the
committed `priv/upstream/openapi.json`, not Zoi or a second handwritten model.
Each is self-contained: component schemas become `$defs`, all local references
are rewritten, and OpenAPI annotations remain available. The schema dialect is
JSON Schema 2020-12, matching the OpenAPI 3.1 source model.

Export is deterministic. Verification compares decoded documents, ignoring
whitespace while detecting missing, malformed, stale and unexpected JSON files.
No network refresh happens implicitly. After intentionally changing the upstream
source, regenerate provider artifacts AND schema exports, then review both diffs.

The wire schema does not encode request-relative correctness: a Choice selected
from the wrong question can be schema-valid. Strict evaluation adds relational
validation. It also imposes the stricter 2..255 Choice and 2..10 Score limits
without rewriting the authoritative wire schema. Exported schemas therefore
remain useful to other languages without claiming to replace semantic validation.
