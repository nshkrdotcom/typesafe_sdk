# Sources and design decisions

Primary supplied sources:

* typesafe_sdk(2).xml: exact implementation baseline; 97 packed files.
* typesend_typesafe_ai.md and typesend_typesafe_ai.xml: semantic DSL, finite caller
  key restoration, enriched Score answers, Prepared, bounded batch evaluation,
  test facade, decision-pattern guides.
* mattneel_typesafe.md and mattneel_typesafe(1).xml: ranked/margin, expected versus
  modal Score, response lookup, tuple/raising constructors, validation paths,
  per-question extras, telemetry metadata, schema export, exact fixture
  distributions/contract checks/sequences and CI/docs ergonomics.
* hfiguera_typesafe.md and hfiguera_typesafe(1).xml: relational response checks,
  probability tolerance, operational privacy and retry ambiguity, bounded-runtime
  requirements, development/held-out evaluation and model-versus-policy metrics.

## Resolved contradictions

The later Matt discussion supersedes the earlier separate Result-wrapper idea:
use the existing response and answer structs, enriched additively. A helper
namespace is not another data model.

Legacy constructors keep their return types; strict tuple/raising constructors
live under Question.*. This resolves the request to improve constructors without
breaking the documented 0.1.x low-level parity API.

Do not repeat typesend's claim that small maps preserve insertion order. Maps
are deterministic only after an explicit sort; ordered pairs preserve caller
order. Use Jason.OrderedObject (already part of the Jason dependency), not a
second serializer. Ordering is an encoding guarantee, NOT a proven model-
accuracy claim. The reported 0.95/0.97 observation is not independently verified.

Strict 2..255 Choice / 2..10 Score constraints reflect the supplied comparison
implementations. The bounded OpenAPI's weaker minItems remains unchanged and
exported faithfully. Do not rewrite historical upstream provenance as if these
semantic limits had been measured in this implementation session.

Gate thresholds are mandatory, never built-in risk policy. Noul confidence is
max(p, 1-p), a convenience measure and not calibration evidence. Rounded Score
expectation and most-probable level remain distinct.

Transport backpressure, streaming byte caps and physical cancellation are NOT
invented SDK implementations. Provide explicit capability reporting/requirements
and handoff checks, with unverified default claims. Preserve Pristine-owned
runtime semantics and default retry policy.

Unknown future answer tags are retained/skipped, but known malformed answers and
known response/request inconsistencies fail validation. No arbitrary response
atomization. Local errors have component-list paths as well as legacy-readable
field_path strings.

## External API references consulted (implementation mechanics only)

* https://elixir.hexdocs.pm/1.18.4/Task.Supervisor.html
  Task.Supervisor.async_stream_nolink, task timeouts, zip_input_on_exit and cleanup.
* https://github.com/elixir-lang/elixir/blob/v1.18.4/lib/elixir/lib/task/supervised.ex
  Ordered streams replenish active-task slots while earlier results are pending.
  SDK-specific finite windows therefore bound ordered prefetch/completion storage;
  this is a scheduling tradeoff, not a replacement HTTP runtime.
* https://hexdocs.pm/jason/1.4.5/Jason.OrderedObject.html
  JSON object property-order preservation from a list of pairs.
* https://jason.hexdocs.pm/Jason.Fragment.html
  Reusing already-encoded JSON without constructing a second serializer.
* https://elixir.hexdocs.pm/1.18.4/Path.html
  The existing maintenance bootstrap's relative path API compatibility.

The attached sources remain authoritative for feature selection and baseline
behavior. These external references do not establish any TypeSafe service SLA,
rate limit, accuracy, billing guarantee or unsupported Pristine capability.

## Provenance/licensing

Implement original integration code from the described ideas rather than copying
whole transport stacks or external documentation. Keep the baseline MIT license.
Credit the three supplied repositories as design influences in the new guide.
