defmodule TypeSafeSDK.ProviderProfile do
  @moduledoc false

  alias Pristine.SDK.ProviderProfile
  alias TypeSafeSDK.RetryPolicy

  @server_error_range 500..599

  @spec profile(RetryPolicy.t() | false | nil) :: ProviderProfile.t()
  def profile(retry_policy \\ %RetryPolicy{})

  def profile(nil), do: profile(%RetryPolicy{})

  def profile(false) do
    build_profile([], false, false)
  end

  def profile(%RetryPolicy{} = retry_policy) do
    build_profile(
      Enum.to_list(retry_policy.http_statuses),
      retry_policy.api_connection_error,
      retry_policy.api_timeout_error
    )
  end

  defp build_profile(http_statuses, api_connection_error, api_timeout_error) do
    use_server_error_range? =
      Enum.all?(@server_error_range, &Enum.member?(http_statuses, &1))

    exact_statuses =
      http_statuses
      |> Enum.reject(&(&1 == 429 or (use_server_error_range? and &1 in @server_error_range)))

    exact_overrides =
      Map.new(exact_statuses, fn status ->
        {status, retry_override(status)}
      end)

    range_overrides =
      if use_server_error_range? do
        [
          %{
            range: @server_error_range,
            retry?: true,
            telemetry_classification: :upstream_failure,
            breaker_outcome: :failure
          }
        ]
      else
        []
      end

    ProviderProfile.new!(
      provider: :typesafe,
      default_retry_group: "typesafe.default",
      # HTTP status retryability is expressed explicitly below so caller-supplied
      # RetryPolicy.http_statuses can remove Pristine's generic retry statuses.
      retryable_groups: [],
      transport_retry_groups: if(api_connection_error or api_timeout_error, do: :all, else: []),
      rate_limit_retry_groups: if(429 in http_statuses, do: :all, else: []),
      status_retry_overrides: exact_overrides,
      # Added by Pristine 0.3.0. Exact status overrides take precedence over ranges.
      status_retry_ranges: range_overrides,
      status_code_map: %{
        400 => :bad_request,
        401 => :authentication,
        403 => :permission_denied,
        404 => :not_found,
        422 => :unprocessable_entity,
        429 => :rate_limit
      },
      request_id_headers: ["x-typesafe-request-id"],
      message_fields: ["message"],
      rate_limit_code: :rate_limit,
      response_error_code: :api_error,
      connection_code: :connection,
      validation_code: :response_validation
    )
  end

  defp retry_override(status) when status in @server_error_range do
    %{
      retry?: true,
      telemetry_classification: :upstream_failure,
      breaker_outcome: :failure
    }
  end

  defp retry_override(408) do
    %{
      retry?: true,
      telemetry_classification: :request_timeout,
      breaker_outcome: :failure
    }
  end

  defp retry_override(_status) do
    %{
      retry?: true,
      telemetry_classification: :client_error,
      breaker_outcome: :ignore
    }
  end
end
