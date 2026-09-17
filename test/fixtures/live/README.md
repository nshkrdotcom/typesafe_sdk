# Approved live fixtures

No live responses were fabricated or imported from another SDK for 0.2.0.
Run `mix typesafe.record --output tmp/live` with a real API key. Review the
synthetic-input response bodies, model versions and capture metadata, then copy
approved `models.json` and `system-one.json` here. Keep metadata with the review
record, not the baseline (timestamps and request IDs change on every request).

Subsequent captures write diffs to the output directory and never overwrite this
baseline. Probabilities/token counts can change without a schema regression;
review differences rather than assuming byte-for-byte model determinism.
The scheduled workflow is disabled unless TYPESAFE_LIVE_ENABLED is set to true.
