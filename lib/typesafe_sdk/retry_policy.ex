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

  @doc """
  Merge a per-call retry override into a client policy.

  Omitted keys inherit from the client policy. `false` explicitly disables
  retries. A complete `%RetryPolicy{}` is already fully resolved and replaces
  the inherited policy. When a disabled client is explicitly re-enabled with a
  keyword/map override, omitted fields inherit the SDK policy defaults.
  """
  @spec merge(t() | false | nil, t() | keyword() | map() | false | nil) ::
          {:ok, t() | false} | {:error, TypeSafeSDK.Error.t()}
  def merge(base, override)
  def merge(base, nil), do: {:ok, normalize_base(base)}
  def merge(_base, false), do: {:ok, false}
  def merge(_base, %__MODULE__{} = override), do: {:ok, override}

  def merge(base, override) when is_list(override) or is_map(override) do
    with {:ok, attrs} <- override_attrs(override) do
      inherited = base |> normalize_base() |> enabled_base() |> Map.from_struct()
      new(Map.merge(inherited, attrs))
    end
  end

  def merge(_base, _override),
    do: {:error, TypeSafeSDK.Error.configuration("invalid retry override")}

  @spec merge!(t() | false | nil, t() | keyword() | map() | false | nil) :: t() | false
  def merge!(base, override) do
    case merge(base, override) do
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

  defp normalize_base(nil), do: %__MODULE__{}
  defp normalize_base(false), do: false
  defp normalize_base(%__MODULE__{} = policy), do: policy

  defp enabled_base(false), do: %__MODULE__{}
  defp enabled_base(%__MODULE__{} = policy), do: policy

  defp override_attrs(attrs) when is_list(attrs) do
    cond do
      not Keyword.keyword?(attrs) ->
        {:error, TypeSafeSDK.Error.configuration("retry override must be a keyword list")}

      length(Keyword.keys(attrs)) != length(Enum.uniq(Keyword.keys(attrs))) ->
        {:error,
         TypeSafeSDK.Error.configuration("duplicate retry override options are not allowed")}

      true ->
        {:ok, Map.new(attrs)}
    end
  end

  defp override_attrs(attrs) when is_map(attrs) and not is_struct(attrs), do: {:ok, attrs}

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
