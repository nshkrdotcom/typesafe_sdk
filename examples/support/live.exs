defmodule TypeSafeSDK.Examples.Live do
  @moduledoc false

  alias TypeSafeSDK.{Client, Constants, Error, Response}

  @live_transport Pristine.Adapters.Transport.Finch
  @default_timeout_ms 15_000

  def client(opts \\ []) when is_list(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError, "live example options must be a keyword list"
    end

    api_key = selected_value(opts, :api_key, Constants.api_key_env())
    base_url = selected_value(opts, :base_url, Constants.base_url_env())
    model = selected_value(opts, :model, Constants.default_model_env())
    retry = Keyword.get(opts, :retry) || false

    opts =
      opts
      |> Keyword.drop([:api_key, :base_url, :model, :transport, :transport_opts, :retry])
      |> maybe_put(:api_key, api_key)
      |> maybe_put(:base_url, base_url)
      |> maybe_put(:model, model)
      |> Keyword.put(:retry, retry)
      |> put_default_timeout()
      |> Keyword.put(:transport, @live_transport)
      |> Keyword.put(:transport_opts, [])

    # Live examples always use the real Pristine HTTP adapter. Endpoint/model
    # selection stays configurable; fixture transports and replay do not.
    TypeSafeSDK.new_client(opts)
  end

  def show_configuration(%Client{} = client) do
    show("Live configuration", %{
      endpoint: safe_endpoint(client),
      model: client.default_model,
      request_timeout_ms: client.timeout_ms,
      retries: if(client.retry == false, do: :disabled, else: :enabled),
      transport: @live_transport
    })
  end

  def safe_endpoint(%Client{base_url: base_url}) do
    # Client validation rejects URL credentials/query strings/fragments. Rebuild
    # only those safe URL components rather than inspecting the client struct.
    uri = URI.parse(base_url)
    URI.to_string(%{uri | userinfo: nil, query: nil, fragment: nil})
  end

  def unwrap!({:ok, value}), do: value

  def unwrap!({:error, %Error{} = error}) do
    show("Request failure", Error.metadata(error))
    raise error
  end

  def show(label, value) do
    IO.puts("\n#{label}")
    IO.inspect(value, pretty: true, limit: :infinity, width: 100)
  end

  def summary(response), do: Response.metadata(response)

  defp selected_value(opts, key, env_name) do
    case Keyword.fetch(opts, key) do
      {:ok, nil} -> env_value(env_name)
      {:ok, value} -> value
      :error -> env_value(env_name)
    end
  end

  defp env_value(name) do
    case System.get_env(name) do
      nil ->
        nil

      value ->
        case String.trim(value) do
          "" ->
            raise ArgumentError,
                  "#{name} is set but blank; unset it or provide an explicit non-blank value"

          trimmed ->
            trimmed
        end
    end
  end

  defp put_default_timeout(opts) do
    if Keyword.get(opts, :timeout_ms) || Keyword.get(opts, :timeout),
      do: opts,
      else: Keyword.put(opts, :timeout_ms, @default_timeout_ms)
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
