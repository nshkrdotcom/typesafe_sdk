# Semantic Questions and Prepared Sets

`evaluate` is the strict Elixir interface. `system_one` remains the Python-parity
escape hatch. Both use generated operations and the same Pristine client.

## Constructor contracts

```elixir
{:ok, q} = TypeSafeSDK.Question.Noul.new("Urgent?", true: "Time-sensitive")
q = TypeSafeSDK.Question.Noul.new!("Urgent?", false: "Routine")
q = TypeSafeSDK.noul("Urgent?", criteria: %{"true" => "Time-sensitive"})

{:ok, team} = TypeSafeSDK.Question.Choice.new("Which team?",
  billing: "Money", technical: "Product")
severity = TypeSafeSDK.score("Impact?", [
  {"Low", "Cosmetic only"}, {"High", %{impact: "Blocking", workaround: false}}
])
```

Strict Choice accepts 2..255 distinct atom/string options. Pair lists preserve
caller order; maps sort by wire key. Order is carried into JSON, including maps
larger than the small-map representation. Noul accepts only true/false criteria;
explicit `criteria:` cannot be combined with shorthand true/false options.
Score accepts 2..10 levels in caller order. A `{label, description}` level becomes
a structured JSON object, retaining the local label for answers.
These are semantic-layer constraints, not changes to committed OpenAPI or the
legacy constructors (whose Score minimum remains one).

Instructions/descriptions accept nonblank strings, JSON maps/lists or nil where
optional. Score levels cannot be nil. JSON objects allow atom/string keys but
reject collisions such as `:team` and `"team"`. JSON values reject arbitrary
atoms, tuples, structs, PIDs, functions and invalid UTF-8. Nesting is bounded to
64 levels. Structured state is sent as JSON, never stringified as Elixir terms.

## Extras, unknown types and validation paths

```elixir
q = TypeSafeSDK.noul("Is this relevant?", extra: %{future_flag: true})
{:ok, prepared} = TypeSafeSDK.prepare(%{
  "future" => %{"type" => "future_primitive", "instructions" => "Evaluate", "new_field" => 3}
})
```

Question `extra` cannot replace `type`, `instructions` or `criteria`. Strict
`evaluate` similarly prevents `extra_body` from replacing state, model or
questions. Legacy `system_one` retains its last-write-wins top-level merge.
Unknown question types remain usable, while unknown answer types remain in raw
response data and `unknown_answers` rather than being coerced to known structs.

`Question.validate/1` returns `:ok` or `{:error, Error}`; `validate!/1` returns its
input or raises. Constructor/preparation failures use `:invalid_request` and
carry both `error.path` components and `error.field_path` for display. Prefer the
component list when IDs contain dots. Details describe the violated invariant;
validation never converts incoming strings into atoms.

## Prepare once

```elixir
prepared = TypeSafeSDK.prepare!(team: team, severity: severity)
TypeSafeSDK.evaluate(client, "first state", prepared)
TypeSafeSDK.evaluate(client, "second state", prepared)
```

Preparation validates and JSON-encodes questions once, stores finite identity
registries, and injects only SDK-produced JSON through `Jason.Fragment` during
subsequent calls. Never construct or mutate Prepared fields directly. Each state
still receives JSON validation; each known answer receives relational checks.
Legacy question structs also work with `prepare`, subject to strict constraints.

Improper lists are rejected as invalid arrays, keyed collections or Score levels;
they are not forwarded or treated as partially valid input. Response validation
also retains unambiguous path components when an answer ID itself contains dots.
