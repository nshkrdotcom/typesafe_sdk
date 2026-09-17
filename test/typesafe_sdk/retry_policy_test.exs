defmodule TypeSafeSDK.RetryPolicyTest do
  use ExUnit.Case, async: true

  alias TypeSafeSDK.RetryPolicy

  test "defaults match the supplied Python SDK" do
    policy = RetryPolicy.new!()
    assert policy.max_retries == 2
    assert policy.backoff_initial == 0.5
    assert policy.backoff_max == 5.0
    assert policy.backoff_jitter == 0.25
    assert policy.timeout == 30.0
    assert MapSet.member?(policy.http_statuses, 408)
    assert MapSet.member?(policy.http_statuses, 429)
    assert MapSet.member?(policy.http_statuses, 599)
  end

  test "normalizes list status input" do
    policy = RetryPolicy.new!(http_statuses: [409, 503])
    assert policy.http_statuses == MapSet.new([409, 503])
  end

  test "an unlimited per-call budget explicitly clears the client budget" do
    options = RetryPolicy.to_pristine_opts(RetryPolicy.new!(timeout: nil))
    assert Keyword.fetch!(options, :retry_budget_ms) == nil
  end

  test "rejects invalid values" do
    assert {:error, _} = RetryPolicy.new(max_retries: -1)
    assert {:error, _} = RetryPolicy.new(backoff_jitter: 1.1)
    assert {:error, _} = RetryPolicy.new(timeout: 0)
    assert {:error, _} = RetryPolicy.new(http_statuses: [99, 600])
  end
end
