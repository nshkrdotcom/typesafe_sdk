defmodule TypeSafeSDK.ResultClassifier do
  @moduledoc false
  @behaviour Pristine.Ports.ResultClassifier

  alias Pristine.Adapters.ResultClassifier.HTTP
  alias Pristine.SDK.Context
  alias TypeSafeSDK.{ProviderProfile, RetryPolicy}

  @impl true
  def classify(result, endpoint, context, opts) do
    policy = retry_policy(opts)

    result
    |> HTTP.classify(endpoint, ensure_profile(context, policy), opts)
    |> apply_transport_policy(result, policy)
    |> apply_retry_after_policy(policy)
  end

  defp retry_policy(opts) when is_list(opts) do
    case Keyword.get(opts, :typesafe_retry_policy, %RetryPolicy{}) do
      false -> false
      %RetryPolicy{} = policy -> policy
      _other -> %RetryPolicy{}
    end
  end

  defp retry_policy(_opts), do: %RetryPolicy{}

  defp ensure_profile(nil, policy),
    do: Context.new(provider_profile: ProviderProfile.profile(policy))

  defp ensure_profile(context, policy) when is_map(context) do
    Map.put(context, :provider_profile, ProviderProfile.profile(policy))
  end

  defp ensure_profile(_context, policy),
    do: Context.new(provider_profile: ProviderProfile.profile(policy))

  defp apply_transport_policy(classification, {:error, reason}, false) do
    set_retryable(classification, false)
    |> maybe_clear_limiter_backoff()
    |> then(fn classification ->
      if timeout_reason?(reason),
        do: %{classification | breaker_outcome: :failure},
        else: classification
    end)
  end

  defp apply_transport_policy(classification, {:error, reason}, %RetryPolicy{} = policy) do
    retryable =
      if timeout_reason?(reason),
        do: policy.api_timeout_error,
        else: policy.api_connection_error

    set_retryable(classification, retryable)
  end

  defp apply_transport_policy(classification, _result, _policy), do: classification

  defp apply_retry_after_policy(classification, false) do
    %{classification | retry_after_ms: nil}
    |> maybe_clear_limiter_backoff()
  end

  defp apply_retry_after_policy(classification, %RetryPolicy{respect_retry_after: false}) do
    %{classification | retry_after_ms: nil}
    |> maybe_clear_limiter_backoff()
  end

  defp apply_retry_after_policy(classification, _policy), do: classification

  defp set_retryable(classification, retryable) when is_map(classification) do
    telemetry = Map.put(classification.telemetry, :retryable, retryable)
    %{classification | retry?: retryable, telemetry: telemetry}
  end

  defp maybe_clear_limiter_backoff(classification) when is_map(classification) do
    %{classification | limiter_backoff_ms: nil}
  end

  defp timeout_reason?(reason), do: TypeSafeSDK.TransportError.timeout?(reason)
end
