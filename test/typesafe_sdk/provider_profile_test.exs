defmodule TypeSafeSDK.ProviderProfileTest do
  use ExUnit.Case, async: true

  alias Pristine.SDK.ProviderProfile, as: RuntimeProfile
  alias TypeSafeSDK.{ProviderProfile, RetryPolicy}

  test "default retry policy uses the Pristine 0.3 status range contract" do
    profile = ProviderProfile.profile(%RetryPolicy{})

    assert [%{range: 500..599, retry?: true}] = profile.status_retry_ranges
    assert RuntimeProfile.status_retry_override(profile, 500).retry? == true
    assert RuntimeProfile.status_retry_override(profile, 550).retry? == true
    assert RuntimeProfile.status_retry_override(profile, 599).retry? == true
    assert RuntimeProfile.status_retry_override(profile, 499) == nil
    assert RuntimeProfile.status_retry_override(profile, 600) == nil
  end

  test "custom status policy can remove the default server-error range" do
    policy = RetryPolicy.new!(http_statuses: [409])
    profile = ProviderProfile.profile(policy)

    assert profile.status_retry_ranges == []
    assert RuntimeProfile.status_retry_override(profile, 409).retry? == true
    assert RuntimeProfile.status_retry_override(profile, 500) == nil
    assert profile.retryable_groups == []
    assert profile.rate_limit_retry_groups == []
  end

  test "429 remains controlled by the rate-limit path" do
    profile = ProviderProfile.profile(RetryPolicy.new!(http_statuses: [429]))
    assert profile.rate_limit_retry_groups == :all
    assert RuntimeProfile.status_retry_override(profile, 429) == nil
  end
end
