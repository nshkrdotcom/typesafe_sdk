# Live example

For the 0.2.0 semantic, bounded-batch and labeled-decision workflow, see
[evaluation/README.md](evaluation/README.md). This existing live script continues
to demonstrate the retained wire-parity API.

Run from the repository root with `TYPESAFE_API_KEY` set:

```bash
mix run examples/live_evaluation.exs
```

With the workstation's secrets helper:

```bash
~/scripts/with_bash_secrets mix run examples/live_evaluation.exs
```

The script calls the real API at `https://api.typesafe.ai`. It lists models and
evaluates a sample billing ticket with `jev-latest`. There is no mocked or offline
mode. A missing API key or failed API request exits with a nonzero status.

The output shows:

- `ListModelsResponse.models`, containing typed `ModelMetadata` structs.
- The input state and typed `Noul`, `Choice`, and `Score` questions.
- `SystemOneResponse.answers`, containing `NoulAnswer`, `ChoiceAnswer`, and
  `ScoreAnswer` structs, including probabilities, confidence, and score legend.
- The selected model, typed token usage, and individual answer values.

The two operations return `ListModelsResponse` and `SystemOneResponse`. The script
prints their useful fields without the raw HTTP metadata. Values come from the
live service and can vary between runs. Edit `state` and `questions` in
[`live_evaluation.exs`](https://github.com/nshkrdotcom/typesafe_sdk/blob/main/examples/live_evaluation.exs)
to try your own input. The script is also included under `examples/` in the Hex package.

For a source checkout using local Pristine tooling, the existing workstation
wrapper also works:

```bash
~/scripts/with_bash_secrets ~/.local/bin/typesafe-mix run examples/live_evaluation.exs
```
