Code.require_file("../../examples/evaluation/evaluation.exs", __DIR__)

defmodule TypeSafeSDK.EvaluationExampleTest do
  use ExUnit.Case, async: true
  alias TypeSafeSDK.Examples.Evaluation, as: Eval
  @policy %{"confidence" => 0.8, "urgency" => 0.85}

  test "development and held-out datasets are disjoint and accept ambiguous labels" do
    dev = Eval.load!("examples/evaluation/datasets/development.jsonl", "development")
    held = Eval.load!("examples/evaluation/datasets/held-out.jsonl", "held-out")
    assert MapSet.disjoint?(MapSet.new(dev, & &1["id"]), MapSet.new(held, & &1["id"]))
    assert Enum.any?(dev, &(length(&1["departments"]) > 1))

    assert_raise ArgumentError, fn ->
      Eval.load!("examples/evaluation/datasets/held-out.jsonl", "development")
    end
  end

  test "model correctness and policy correctness have distinct denominators" do
    rows = [
      record("one", "billing", ["billing"], ["billing"], 0.9, 0.1, 10),
      record("two", "technical", ["technical"], ["urgent"], 0.95, 0.1, 20),
      record("three", "sales", ["sales"], ["review"], 0.3, 0.1, 30),
      %{
        "id" => "failed",
        "outcome" => "error",
        "departments" => ["technical"],
        "routes" => ["urgent"],
        "latency_ms" => 40
      }
    ]

    metrics = Eval.metrics(rows, @policy)
    assert metrics["model_accuracy"] == 1.0
    assert_in_delta metrics["policy_accuracy"], 2 / 3, 0.00001
    assert metrics["end_to_end_policy_accuracy"] == 0.5
    assert metrics["automatic_coverage"] == 0.5
    assert metrics["automatic_error_rate"] == 0.5
    assert metrics["failures"] == 1
    assert metrics["latency_p50_ms"] == 20
    assert metrics["latency_p95_ms"] == 40
    assert metrics["input_tokens"] == 6
  end

  test "empty denominators are null, never fabricated perfect accuracy" do
    metrics = Eval.metrics([], @policy)
    assert metrics["model_accuracy"] == nil
    assert metrics["automatic_error_rate"] == nil
    assert metrics["latency_p95_ms"] == nil
  end

  test "sweeps are development-only, use existing predictions, and enforce the declared constraint" do
    records = [record("one", "billing", ["billing"], ["billing"], 0.9, 0.1, 10)]
    sweep = Eval.sweep(records, "development")
    policy = Eval.select_policy!(sweep, 0.0)
    assert policy["confidence"] <= 0.9
    assert_raise ArgumentError, fn -> Eval.sweep(records, "held-out") end
    assert_raise ArgumentError, fn -> Eval.select_policy!(Eval.sweep([], "development"), 0.05) end
  end

  test "the runnable example evaluates through the real SDK and excludes state from reports" do
    client =
      TypeSafeSDK.Test.client()
      |> TypeSafeSDK.Test.stub(
        department: {:choice, :billing, 0.9},
        urgent: {:noul, 0.1}
      )

    rows = [
      %{
        "id" => "example",
        "split" => "development",
        "state" => "private-state",
        "departments" => ["billing"],
        "routes" => ["billing"]
      }
    ]

    [record] = Eval.run(client, rows)
    assert record["department"] == "billing"
    refute Map.has_key?(record, "state")
    assert Eval.metrics([record], @policy)["policy_accuracy"] == 1.0
    assert TypeSafeSDK.Test.verify!(client) == :ok
  end

  defp record(id, department, expected, routes, confidence, urgent, latency) do
    %{
      "id" => id,
      "outcome" => "ok",
      "department" => department,
      "departments" => expected,
      "routes" => routes,
      "confidence" => confidence,
      "urgent" => urgent,
      "latency_ms" => latency,
      "input_tokens" => 2,
      "output_tokens" => 1,
      "model" => "jev-test"
    }
  end

  test "unknown future answers become reported example failures, not a crashed report" do
    row = %{
      "id" => "future",
      "split" => "development",
      "departments" => ["billing"],
      "routes" => ["review"]
    }

    response = %TypeSafeSDK.SystemOneResponse{
      model: "jev",
      usage: %TypeSafeSDK.Usage{},
      answers: %{},
      unknown_answers: %{"department" => %{"type" => "future"}}
    }

    record = Eval.record(row, {:ok, response})
    assert record["outcome"] == "error"
    assert record["error_type"] == "unsupported_answer"
    assert Eval.metrics([record], @policy)["failures"] == 1
  end
end
