defmodule TypeSafeSDK.Client do
  @moduledoc """
  Thin TypeSafe API client layered on Pristine.

  Runtime code does not read OS environment variables. Explicit options win over
  application config; the included `config/runtime.exs` materializes the Python
  SDK-compatible environment names when this repo is the top-level Mix project.
  """

  alias Pristine.Adapters.Auth.Bearer
  alias Pristine.Client, as: RuntimeClient
  alias Pristine.SDK.OpenAPI.Client, as: OpenAPIClient

  alias TypeSafeSDK.{
    Constants,
    Error,
    ProviderProfile,
    RequestBudget,
    ResponseContract,
    RetryPolicy
  }

  @protected_headers MapSet.new([
                       "authorization",
                       "accept",
                       "content-type",
                       "user-agent",
                       "x-typesafe-sdk",
                       "x-typesafe-runtime",
                       "x-typesafe-retry-count"
                     ])

  @type t :: %__MODULE__{
          api_key: String.t(),
          base_url: String.t(),
          default_model: String.t(),
          timeout_ms: pos_integer(),
          retry: RetryPolicy.t() | false,
          response_contract: %{
            required(:on_unknown_answer) => :preserve | :error,
            required(:allowed_models) => [String.t()] | nil
          },
          max_request_bytes: pos_integer() | nil,
          headers: map(),
          transport: module(),
          transport_opts: keyword(),
          context: Pristine.SDK.Context.t(),
          pristine_client: RuntimeClient.t()
        }

  defstruct [
    :api_key,
    :base_url,
    :default_model,
    :timeout_ms,
    :retry,
    :response_contract,
    :max_request_bytes,
    :headers,
    :transport,
    :transport_opts,
    :context,
    :pristine_client
  ]

  @spec new(keyword()) :: t()
  def new(opts \\ []) when is_list(opts) do
    api_key = resolve_required_string(opts, :api_key, nil)

    base_url =
      resolve_string(opts, :base_url, Constants.default_base_url()) |> String.trim_trailing("/")

    default_model = resolve_string(opts, :model, config(:default_model, Constants.default_model()))
    timeout_ms = resolve_timeout_ms(opts)
    retry = resolve_retry(option_or_config(opts, :retry, %RetryPolicy{}))
    response_contract = resolve_response_contract(option_or_config(opts, :response_contract, nil))
    max_request_bytes = resolve_max_request_bytes(option_or_config(opts, :max_request_bytes, nil))
    headers = opts |> Keyword.get(:headers, %{}) |> normalize_headers() |> sanitize_extra_headers()
    transport = Keyword.get(opts, :transport, config(:transport, Pristine.Adapters.Transport.Finch))
    transport_opts = Keyword.get(opts, :transport_opts, config(:transport_opts, []))

    client = %__MODULE__{
      api_key: api_key,
      base_url: base_url,
      default_model: default_model,
      timeout_ms: timeout_ms,
      retry: retry,
      response_contract: response_contract,
      max_request_bytes: max_request_bytes,
      headers: headers,
      transport: transport,
      transport_opts: transport_opts
    }

    context = build_context(client)
    client = %{client | context: context, pristine_client: RuntimeClient.from_context(context)}

    TypeSafeSDK.RuntimeCapabilities.require!(
      client,
      Keyword.get(opts, :runtime_requirements, [])
    )

    client
  end

  @spec pristine_client(t()) :: RuntimeClient.t()
  def pristine_client(%__MODULE__{pristine_client: %RuntimeClient{} = client}), do: client

  @doc false
  @spec execute_generated_request(t(), map()) :: {:ok, term()} | {:error, term()}
  def execute_generated_request(%__MODULE__{} = client, request) when is_map(request) do
    call_opts = normalize_call_opts(Map.get(request, :opts, []))

    extra_headers =
      call_opts
      |> Keyword.get(:extra_headers, %{})
      |> normalize_headers()
      |> sanitize_extra_headers()

    request_spec =
      request
      |> OpenAPIClient.to_request_spec()
      |> Map.update!(:headers, &Map.merge(normalize_headers(&1), extra_headers))
      |> Map.put(:request_schema, nil)
      |> Map.put(:response_schema, nil)

    retry_policy = retry_override_policy(call_opts, client.retry)

    execute_opts =
      []
      |> maybe_put(:timeout, timeout_override_ms(call_opts))
      |> maybe_put(:cancellation, Keyword.get(call_opts, :cancellation))
      |> Keyword.put(:retry_opts, RetryPolicy.to_pristine_opts(retry_policy))
      |> Keyword.put(:typesafe_retry_policy, retry_policy)
      |> Keyword.put(:response, :wrapped)

    context = %{client.context | provider_profile: ProviderProfile.profile(retry_policy)}

    case Pristine.execute_request(request_spec, context, execute_opts) do
      {:error, %Pristine.Error{type: :cancelled} = cause} -> {:error, Error.cancelled(cause)}
      result -> result
    end
  end

  @spec extra_headers(term()) :: map()
  def extra_headers(opts) when is_list(opts) do
    case Keyword.get(opts, :retry_count, 0) do
      count when is_integer(count) and count > 0 ->
        %{"X-TypeSafe-Retry-Count" => Integer.to_string(count)}

      _ ->
        %{}
    end
  end

  defp build_context(%__MODULE__{} = client) do
    # Pristine probes optional wrapper callbacks with function_exported?/3.
    # Load our wrapper before the first request, including cold host startup.
    Code.ensure_loaded!(TypeSafeSDK.TransportResponse)

    Pristine.foundation_context(
      auth: [Bearer.new(client.api_key)],
      base_url: client.base_url,
      default_timeout: client.timeout_ms,
      headers: Map.merge(client.headers, system_headers()),
      error_module: Error,
      extra_headers: &__MODULE__.extra_headers/1,
      log_level: config(:log_level, :warn),
      package_version: TypeSafeSDK.version(),
      provider_profile: ProviderProfile.profile(client.retry),
      result_classifier: TypeSafeSDK.ResultClassifier,
      response_wrapper: TypeSafeSDK.TransportResponse,
      retry: [
        adapter: Pristine.Adapters.Retry.Foundation,
        opts: RetryPolicy.to_pristine_opts(client.retry)
      ],
      serializer: Pristine.Adapters.Serializer.JSON,
      transport: client.transport,
      transport_opts: client.transport_opts
    )
  end

  defp system_headers do
    version = TypeSafeSDK.version()
    sdk = "typesafe-sdk/#{version}"

    %{
      "Accept" => "application/json",
      "User-Agent" => sdk,
      "X-TypeSafe-SDK" => sdk,
      "X-TypeSafe-Runtime" => runtime_header()
    }
  end

  defp runtime_header do
    os = :os.type() |> Tuple.to_list() |> Enum.map_join("/", &to_string/1)
    arch = :erlang.system_info(:system_architecture) |> to_string()
    "elixir/#{System.version()} (#{os}; #{arch})"
  end

  defp resolve_required_string(opts, key, fallback) do
    case option_or_config(opts, key, fallback) do
      value when is_binary(value) ->
        case String.trim(value) do
          "" ->
            raise Error.configuration(
                    "No API key was provided; pass :api_key or configure :typesafe_sdk, :api_key"
                  )

          trimmed ->
            trimmed
        end

      _ ->
        raise Error.configuration(
                "No API key was provided; pass :api_key or configure :typesafe_sdk, :api_key"
              )
    end
  end

  defp resolve_string(opts, key, fallback) do
    case option_or_config(opts, key, fallback) do
      value when is_binary(value) ->
        case String.trim(value) do
          "" -> fallback
          trimmed -> trimmed
        end

      _ ->
        fallback
    end
  end

  defp resolve_timeout_ms(opts) do
    cond do
      non_nil_keyword?(opts, :timeout_ms) -> validate_timeout_ms!(Keyword.fetch!(opts, :timeout_ms))
      non_nil_keyword?(opts, :timeout) -> opts |> Keyword.fetch!(:timeout) |> seconds_to_ms!()
      true -> config(:timeout_ms, Constants.default_timeout_ms()) |> validate_timeout_ms!()
    end
  end

  defp timeout_override_ms(opts) do
    cond do
      non_nil_keyword?(opts, :timeout_ms) -> validate_timeout_ms!(Keyword.fetch!(opts, :timeout_ms))
      non_nil_keyword?(opts, :timeout) -> opts |> Keyword.fetch!(:timeout) |> seconds_to_ms!()
      true -> nil
    end
  end

  defp seconds_to_ms!(value) when is_number(value) and value > 0 do
    if finite_number?(value), do: round(value * 1_000), else: invalid_timeout!()
  end

  defp seconds_to_ms!(_value), do: invalid_timeout!()

  defp validate_timeout_ms!(value) when is_integer(value) and value > 0, do: value

  defp validate_timeout_ms!(value) when is_float(value) and value > 0 do
    if finite_number?(value),
      do: round(value),
      else: raise(Error.configuration("timeout_ms must be a positive finite number"))
  end

  defp validate_timeout_ms!(_),
    do: raise(Error.configuration("timeout_ms must be a positive number"))

  defp resolve_retry(nil), do: %RetryPolicy{}
  defp resolve_retry(false), do: false
  defp resolve_retry(%RetryPolicy{} = policy), do: policy
  defp resolve_retry(opts) when is_list(opts) or is_map(opts), do: RetryPolicy.new!(opts)

  defp resolve_retry(other),
    do: raise(Error.configuration("invalid retry policy: #{inspect(other)}"))

  defp retry_override_policy(opts, default) do
    case Keyword.fetch(opts, :retry) do
      :error -> default
      {:ok, override} -> RetryPolicy.merge!(default, override)
    end
  end

  defp resolve_response_contract(value) do
    case ResponseContract.normalize(value) do
      {:ok, contract} -> contract
      {:error, error} -> raise error
    end
  end

  defp resolve_max_request_bytes(value) do
    case RequestBudget.validate(value, ["max_request_bytes"]) do
      :ok -> value
      {:error, error} -> raise error
    end
  end

  defp normalize_call_opts(opts) when is_list(opts) do
    if Keyword.keyword?(opts),
      do: opts,
      else: raise(ArgumentError, "request opts must be a keyword list")
  end

  defp normalize_call_opts(nil), do: []

  defp normalize_call_opts(other) do
    raise ArgumentError, "request opts must be a keyword list, got: #{inspect(other)}"
  end

  defp sanitize_extra_headers(headers) do
    headers
    |> Enum.reject(fn {key, _value} ->
      MapSet.member?(@protected_headers, String.downcase(to_string(key)))
    end)
    |> Map.new()
  end

  defp normalize_headers(nil), do: %{}

  defp normalize_headers(headers) when is_map(headers) do
    Map.new(headers, fn {key, value} -> {to_string(key), to_string(value)} end)
  end

  defp normalize_headers(headers) when is_list(headers) do
    Map.new(headers, fn {key, value} -> {to_string(key), to_string(value)} end)
  end

  defp normalize_headers(_), do: %{}

  defp option_or_config(opts, key, fallback) do
    case Keyword.fetch(opts, key) do
      {:ok, nil} -> config(key, fallback)
      {:ok, value} -> value
      :error -> config(key, fallback)
    end
  end

  defp non_nil_keyword?(opts, key),
    do: Keyword.has_key?(opts, key) and not is_nil(Keyword.get(opts, key))

  defp finite_number?(value) when is_integer(value), do: true
  defp finite_number?(value) when is_float(value), do: abs(value) < 1.0e308

  defp invalid_timeout!,
    do: raise(Error.configuration("timeout must be a positive finite number of seconds"))

  defp config(key, default), do: Application.get_env(:typesafe_sdk, key, default)
  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
