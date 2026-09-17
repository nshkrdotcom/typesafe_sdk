Code.require_file("evaluation.exs", __DIR__)
Code.require_file("../support/live.exs", __DIR__)

defmodule TypeSafeSDK.Examples.Evaluation.CLI do
  alias TypeSafeSDK.Examples.Evaluation, as: Eval

  def run(args) do
    args = if List.first(args) == "--", do: tl(args), else: args

    {opts, rest, invalid} =
      OptionParser.parse(args,
        strict: [
          split: :string,
          dataset: :string,
          output: :string,
          policy: :string,
          model: :string,
          sweep: :boolean,
          confidence: :float,
          urgency: :float,
          max_auto_error: :float,
          max_concurrency: :integer
        ]
      )

    if rest != [] or invalid != [], do: raise(ArgumentError, "unknown evaluation CLI option")
    split = Keyword.get(opts, :split, "development")

    unless split in ["development", "held-out"],
      do: raise(ArgumentError, "split must be development or held-out")

    sweep? = Keyword.get(opts, :sweep, false)

    if split == "held-out" and (sweep? or not Keyword.has_key?(opts, :policy)),
      do: raise(ArgumentError, "held-out runs require --policy and forbid --sweep")

    if Keyword.has_key?(opts, :policy) and
         (sweep? or Enum.any?([:confidence, :urgency], &Keyword.has_key?(opts, &1))),
       do:
         raise(
           ArgumentError,
           "a frozen policy cannot be combined with --sweep or threshold overrides"
         )

    frozen = read_policy(Keyword.get(opts, :policy))
    model = if frozen, do: frozen["model"], else: Keyword.get(opts, :model, "jev-latest")

    if frozen && Keyword.has_key?(opts, :model) && opts[:model] != model,
      do: raise(ArgumentError, "held-out model must match the frozen policy")

    # Validate all policy/capacity arguments before making billable calls.
    declared_policy =
      Eval.validate_policy!(%{
        "confidence" => Keyword.get(opts, :confidence, 0.8),
        "urgency" => Keyword.get(opts, :urgency, 0.85)
      })

    max_auto_error = Keyword.get(opts, :max_auto_error, 0.05)

    unless is_number(max_auto_error) and max_auto_error >= 0 and max_auto_error <= 1,
      do: raise(ArgumentError, "max-auto-error must be in [0, 1]")

    concurrency = Keyword.get(opts, :max_concurrency, 4)

    unless is_integer(concurrency) and concurrency in 1..1024,
      do: raise(ArgumentError, "max-concurrency must be in 1..1024")

    directory = Path.join(__DIR__, "datasets")
    path = Keyword.get(opts, :dataset, Path.join(directory, split <> ".jsonl"))
    rows = Eval.load!(path, split)
    client = %{TypeSafeSDK.Examples.Live.client() | default_model: model}
    records = Eval.run(client, rows, max_concurrency: concurrency)
    sweep = if sweep?, do: Eval.sweep(records, split), else: []

    {policy, selection_error} =
      cond do
        frozen ->
          {frozen["policy"], nil}

        sweep? ->
          try do
            {Eval.select_policy!(sweep, max_auto_error), nil}
          rescue
            error in ArgumentError -> {nil, Exception.message(error)}
          end

        true ->
          {declared_policy, nil}
      end

    # No eligible policy is an evaluation result, not a reason to discard the
    # already-paid-for predictions. Persist the sweep and records without
    # inventing fallback thresholds or writing a frozen policy.
    metrics = if policy, do: Eval.metrics(records, policy), else: nil
    model_mismatch = frozen && metrics && metrics["models"] != [frozen["model"]]

    report = %{
      "sdk_version" => TypeSafeSDK.version(),
      "split" => split,
      "requested_model" => model,
      "policy" => policy,
      "metrics" => metrics,
      "selection_error" => selection_error,
      "frozen_model_mismatch" => !!model_mismatch,
      "threshold_sweep" => sweep,
      "records" => records,
      "dataset_kind" => "synthetic illustrative dataset; not benchmark evidence"
    }

    output = Keyword.get(opts, :output, "tmp/triage-#{split}.json")
    write!(output, report)

    if split == "development" and not is_nil(metrics) and metrics["successes"] > 0 and
         metrics["failures"] == 0 do
      case metrics["models"] do
        [observed_model] ->
          write!(Path.rootname(output) <> ".policy.json", %{
            "source_split" => "development",
            "model" => observed_model,
            "policy" => policy,
            "source_report" => output
          })

        _ ->
          IO.warn("No frozen policy written: development responses used different model versions")
      end
    end

    IO.puts(Jason.encode!(metrics, pretty: true))
    IO.puts("Wrote #{output}")
    if selection_error, do: IO.warn(selection_error)
    if model_mismatch, do: IO.warn("Observed model differs from the frozen development model")
    if is_nil(metrics) or metrics["failures"] > 0 or model_mismatch, do: System.halt(1)
  end

  defp read_policy(nil), do: nil

  defp read_policy(path) do
    frozen = path |> File.read!() |> Jason.decode!()

    unless frozen["source_split"] == "development" and is_binary(frozen["model"]),
      do: raise(ArgumentError, "policy must be frozen from a development run")

    Eval.validate_policy!(frozen["policy"])
    frozen
  end

  defp write!(path, value) do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, Jason.encode!(value, pretty: true) <> "\n")
  end
end

TypeSafeSDK.Examples.Evaluation.CLI.run(System.argv())
