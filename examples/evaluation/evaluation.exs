defmodule TypeSafeSDK.Examples.Evaluation do
  @moduledoc """
  Runnable support-triage evaluation; example code, not a general SDK framework.
  Model judgment and application policy are measured separately. All bundled
  labels are synthetic illustrative data, not benchmark or calibration evidence.
  """
  @departments ~w(billing technical sales)
  @routes @departments ++ ~w(review urgent)

  def questions do
    TypeSafeSDK.prepare!(
      department: TypeSafeSDK.choice("Which team owns the primary support request?",
        billing: "Charges, invoices, refunds and payments",
        technical: "Bugs, failures, outages and integrations",
        sales: "Purchases, product plans and commercial inquiries"),
      urgent: TypeSafeSDK.noul("Does this require urgent human attention?",
        true: "An active outage, serious business impact or immediate time constraint",
        false: "Routine support, general inquiries or non-blocking work")
    )
  end

  def load!(path, split) when split in ["development", "held-out"] do
    rows = path |> File.stream!() |> Enum.with_index(1) |> Enum.map(fn {line, number} ->
      row = case Jason.decode(line) do
        {:ok, row} when is_map(row) -> row
        _ -> raise ArgumentError, "#{path}:#{number}: expected a JSON object"
      end
      valid = is_binary(row["id"]) and String.trim(row["id"]) != "" and
        row["split"] == split and Map.has_key?(row, "state") and
        labels?(row["departments"], @departments) and labels?(row["routes"], @routes)
      unless valid, do: raise(ArgumentError, "#{path}:#{number}: invalid labels, ID or split")
      case TypeSafeSDK.JSON.normalize(row["state"], ["state"]) do
        {:ok, _} -> row
        {:error, error} -> raise error
      end
    end)
    ids = Enum.map(rows, & &1["id"])
    if rows == [] or length(ids) != length(Enum.uniq(ids)),
      do: raise(ArgumentError, "dataset must be nonempty with distinct IDs")
    rows
  end

  def run(client, rows, opts \\ []) do
    prepared = questions()
    results = TypeSafeSDK.evaluate_many(client, Enum.map(rows, & &1["state"]), prepared,
      max_concurrency: Keyword.get(opts, :max_concurrency, 4), ordered: true,
      on_error: :collect, task_timeout_ms: Keyword.get(opts, :task_timeout_ms, 40_000))
    Enum.zip_with(rows, results, &record/2)
  end

  def record(row, {:ok, response}) do
    with {:ok, %TypeSafeSDK.ChoiceAnswer{} = department} <- TypeSafeSDK.Response.fetch(response, :department),
         {:ok, %TypeSafeSDK.NoulAnswer{} = urgent} <- TypeSafeSDK.Response.fetch(response, :urgent) do
      Map.merge(labels(row), %{
        "outcome" => "ok", "department" => Atom.to_string(department.choice),
        "confidence" => department.confidence, "urgent" => urgent.noul,
        "probabilities" => Map.new(department.probabilities, fn {key, p} -> {Atom.to_string(key), p} end),
        "latency_ms" => response.elapsed_ms, "model" => response.model,
        "request_id" => response.request_id,
        "input_tokens" => response.usage.input_tokens, "output_tokens" => response.usage.output_tokens
      })
    else
      _ -> Map.merge(labels(row), %{
        "outcome" => "error", "error_type" => "unsupported_answer",
        "request_id" => response.request_id, "latency_ms" => response.elapsed_ms
      })
    end
  end
  def record(row, {:error, error}) do
    Map.merge(labels(row), %{"outcome" => "error", "error_type" => Atom.to_string(error.type),
      "status" => error.status, "request_id" => error.request_id,
      "latency_ms" => error.details[:elapsed_ms]})
  end

  def validate_policy!(%{"confidence" => confidence, "urgency" => urgency} = policy) do
    unless probability?(confidence) and probability?(urgency),
      do: raise(ArgumentError, "policy thresholds must be in [0, 1]")
    policy
  end
  def validate_policy!(_), do: raise(ArgumentError, "policy needs confidence and urgency thresholds")

  def route(%{"outcome" => "error"}, _policy), do: "failed"
  def route(record, policy) do
    policy = validate_policy!(policy)
    cond do
      record["urgent"] >= policy["urgency"] -> "urgent"
      record["confidence"] < policy["confidence"] -> "review"
      true -> record["department"]
    end
  end

  def metrics(records, policy) do
    policy = validate_policy!(policy)
    routed = Enum.map(records, &Map.put(&1, "route", route(&1, policy)))
    ok = Enum.filter(routed, &(&1["outcome"] == "ok"))
    automatic = Enum.filter(ok, &(&1["route"] in @departments))
    human = Enum.filter(ok, &(&1["route"] in ["review", "urgent"]))
    required_human = Enum.filter(routed, &Enum.all?(&1["routes"], fn r -> r in ["review", "urgent"] end))
    model_correct = Enum.count(ok, &(&1["department"] in &1["departments"]))
    policy_correct = Enum.count(ok, &(&1["route"] in &1["routes"]))
    auto_errors = Enum.count(automatic, &(&1["route"] not in &1["routes"]))
    human_handled = Enum.count(required_human, &(&1["route"] in ["review", "urgent"]))
    latencies = records |> Enum.map(& &1["latency_ms"]) |> Enum.filter(&is_number/1) |> Enum.sort()
    %{
      "total" => length(records), "successes" => length(ok), "failures" => length(records) - length(ok),
      "model_correct" => model_correct, "policy_correct" => policy_correct,
      "model_accuracy" => ratio(model_correct, length(ok)),
      "policy_accuracy" => ratio(policy_correct, length(ok)),
      "end_to_end_policy_accuracy" => ratio(policy_correct, length(records)),
      "automatic_count" => length(automatic), "automatic_errors" => auto_errors,
      "automatic_coverage" => ratio(length(automatic), length(records)),
      "automatic_error_rate" => ratio(auto_errors, length(automatic)),
      "human_count" => length(human), "human_rate" => ratio(length(human), length(records)),
      "required_human_count" => length(required_human),
      "required_human_recall" => ratio(human_handled, length(required_human)),
      "route_counts" => Enum.frequencies_by(routed, & &1["route"]),
      "latency_observations" => length(latencies),
      "latency_p50_ms" => percentile(latencies, 0.5), "latency_p95_ms" => percentile(latencies, 0.95),
      "input_tokens" => token_sum(ok, "input_tokens"), "output_tokens" => token_sum(ok, "output_tokens"),
      "models" => ok |> Enum.map(& &1["model"]) |> Enum.uniq() |> Enum.sort()
    }
  end

  def sweep(records, split, opts \\ [])

  def sweep(records, "development", opts) do
    confidence = Keyword.get(opts, :confidence, [0.5, 0.65, 0.8, 0.9, 0.95])
    urgency = Keyword.get(opts, :urgency, [0.5, 0.7, 0.85, 0.95])
    for c <- confidence, u <- urgency do
      policy = validate_policy!(%{"confidence" => c, "urgency" => u})
      %{"policy" => policy, "metrics" => metrics(records, policy)}
    end
  end
  def sweep(_, _, _), do: raise(ArgumentError, "threshold sweeps are development-only")

  def select_policy!(sweep, max_auto_error) do
    unless probability?(max_auto_error), do: raise(ArgumentError, "invalid maximum automatic error rate")
    eligible = Enum.filter(sweep, fn row ->
      m = row["metrics"]
      m["successes"] > 0 and m["automatic_count"] > 0 and m["automatic_error_rate"] <= max_auto_error
    end)
    case Enum.sort_by(eligible, fn row ->
      {-row["metrics"]["automatic_coverage"], row["metrics"]["automatic_error_rate"],
        -row["policy"]["confidence"], row["policy"]["urgency"]}
    end) do
      [best | _] -> best["policy"]
      [] -> raise ArgumentError, "no development policy meets the stated automatic-error constraint"
    end
  end

  def percentile([], _p), do: nil
  def percentile(sorted, p), do: Enum.at(sorted, max(ceil(p * length(sorted)) - 1, 0))
  defp labels?(labels, allowed), do: is_list(labels) and labels != [] and Enum.all?(labels, &(&1 in allowed))
  defp labels(row), do: Map.take(row, ["id", "split", "departments", "routes"])
  defp probability?(value), do: is_number(value) and value >= 0 and value <= 1
  defp ratio(_, 0), do: nil
  defp ratio(count, total), do: count / total
  defp token_sum(rows, field) do
    values = Enum.map(rows, & &1[field])
    if Enum.any?(values, &is_nil/1), do: nil, else: Enum.sum(values)
  end
end
