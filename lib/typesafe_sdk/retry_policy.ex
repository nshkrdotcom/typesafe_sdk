defmodule TypeSafeSDK.RetryPolicy do
  @moduledoc """
  Retry configuration matching the public policy of the supplied Python SDK.

  `max_retries` counts retries after the initial request. Backoff values are in
  seconds at this public boundary and are translated to Pristine milliseconds.
  HTTP status membership is applied through the provider profile, so
  per-client and per-call status overrides affect actual retry classification.
  """

  @default_http_statuses [408, 429] ++ Enum.to_list(500..599)

  @enforce_keys []
  defstruct max_retries: 2,
            backoff_initial: 0.5,
            backoff_max: 5.0,
            backoff_jitter: 0.25,
            http_statuses: @default_http_statuses,
            respect_retry_after: true,
            api_connection_error: true,
            api_timeout_error: true,
            timeout: 30.0

  @type t :: %__MODULE__{
          max_retries: non_neg_integer(),
          backoff_initial: number(),
          backoff_max: number(),
          backoff_jitter: float(),
          http_statuses: MapSet.t(integer()) | [integer()],
          respect_retry_after: boolean(),
          api_connection_error: boolean(),
          api_timeout_error: boolean(),
          timeout: number() | nil
        }

  @spec default_http_statuses() :: MapSet.t(integer())
  def default_http_statuses, do: MapSet.new(@default_http_statuses, & &1)

  @spec new(keyword() | map()) :: {:ok, t()} | {:error, TypeSafeSDK.Error.t()}
  def new(opts \\ []) do
    attrs = if is_map(opts), do: opts, else: Map.new(opts)
    attrs = normalize_http_statuses_attr(attrs)
    policy = struct!(__MODULE__, attrs)

    case validate(policy) do
      :ok -> {:ok, policy}
      {:error, message} -> {:error, TypeSafeSDK.Error.configuration(message)}
    end
  rescue
    KeyError -> {:error, TypeSafeSDK.Error.configuration("unknown retry policy option")}
  end

  @spec new!(keyword() | map()) :: t()
  def new!(opts \\ []) do
    case new(opts) do
      {:ok, policy} -> policy
      {:error, error} -> raise error
    end
  end

  @spec to_pristine_opts(t() | false | nil) :: keyword()
  def to_pristine_opts(false), do: [max_attempts: 0]
  def to_pristine_opts(nil), do: to_pristine_opts(%__MODULE__{})

  def to_pristine_opts(%__MODULE__{} = policy) do
    [
      max_attempts: policy.max_retries,
      base_ms: min(seconds_to_ms(policy.backoff_initial), seconds_to_ms(policy.backoff_max)),
      max_ms: seconds_to_ms(policy.backoff_max),
      strategy: :exponential,
      jitter: policy.backoff_jitter,
      jitter_strategy: if(policy.backoff_jitter == 0, do: :none, else: :factor)
    ]
    |> maybe_put_retry_budget(policy.timeout)
  end

  defp normalize_http_statuses_attr(attrs) do
    case Map.fetch(attrs, :http_statuses) do
      :error -> Map.put(attrs, :http_statuses, default_http_statuses())
      {:ok, %MapSet{}} -> attrs
      {:ok, statuses} when is_list(statuses) -> Map.put(attrs, :http_statuses, MapSet.new(statuses))
      {:ok, statuses} -> Map.put(attrs, :http_statuses, statuses)
    end
  end

  defp validate(%__MODULE__{} = policy) do
    cond do
      not (is_integer(policy.max_retries) and policy.max_retries >= 0) ->
        {:error, "max_retries must be a non-negative integer"}

      not finite_nonnegative?(policy.backoff_initial) ->
        {:error, "backoff_initial must be a non-negative finite number of seconds"}

      not finite_nonnegative?(policy.backoff_max) ->
        {:error, "backoff_max must be a non-negative finite number of seconds"}

      not (is_number(policy.backoff_jitter) and policy.backoff_jitter >= 0 and
               policy.backoff_jitter <= 1) ->
        {:error, "backoff_jitter must be between zero and one"}

      true ->
        validate_retry_flags(policy)
    end
  end

  defp validate_retry_flags(policy) do
    cond do
      not match?(%MapSet{}, policy.http_statuses) ->
        {:error, "http_statuses must be a MapSet or list of HTTP status integers"}

      not Enum.all?(policy.http_statuses, &valid_http_status?/1) ->
        {:error, "http_statuses must contain only integers from 100 through 599"}

      not is_boolean(policy.respect_retry_after) ->
        {:error, "respect_retry_after must be a boolean"}

      not is_boolean(policy.api_connection_error) ->
        {:error, "api_connection_error must be a boolean"}

      not is_boolean(policy.api_timeout_error) ->
        {:error, "api_timeout_error must be a boolean"}

      not is_nil(policy.timeout) and not finite_positive?(policy.timeout) ->
        {:error, "timeout must be a positive finite number of seconds or nil"}

      true ->
        :ok
    end
  end

  defp valid_http_status?(status), do: is_integer(status) and status >= 100 and status <= 599
  defp finite_nonnegative?(value), do: is_number(value) and value >= 0 and finite?(value)
  defp finite_positive?(value), do: is_number(value) and value > 0 and finite?(value)

  defp finite?(value) when is_integer(value), do: true
  defp finite?(value) when is_float(value), do: abs(value) < 1.0e308

  defp seconds_to_ms(value), do: value |> Kernel.*(1_000) |> round()

  defp maybe_put_retry_budget(opts, nil), do: Keyword.put(opts, :retry_budget_ms, nil)

  defp maybe_put_retry_budget(opts, timeout) do
    Keyword.put(opts, :retry_budget_ms, seconds_to_ms(timeout))
  end
end
