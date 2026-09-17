defmodule TypeSafeSDK.ListModelsResponse do
  @moduledoc "Typed list of models available to the account."

  alias TypeSafeSDK.{Error, ModelMetadata, TransportResponse}

  @enforce_keys [:models]
  defstruct [:models, :request_id, :raw_http_response, :raw, retries: 0, elapsed_ms: 0]

  @type t :: %__MODULE__{
          models: [ModelMetadata.t()],
          request_id: String.t() | nil,
          raw_http_response: Pristine.Response.t() | nil,
          raw: map() | nil,
          retries: non_neg_integer(),
          elapsed_ms: number()
        }

  @spec decode(term()) :: {:ok, t()} | {:error, Error.t()}
  def decode(%TransportResponse{} = transport) do
    case decode(transport.data) do
      {:ok, response} ->
        {:ok,
         %{
           response
           | request_id: transport.request_id,
             raw_http_response: transport.raw_http_response,
             retries: transport.retries,
             elapsed_ms: transport.elapsed_ms
         }}

      {:error, %Error{} = error} ->
        {:error, Error.attach_response(error, transport.raw_http_response, transport.data)}
    end
  end

  def decode(body) when is_map(body) do
    case Map.get(body, "models") || Map.get(body, :models) do
      models when is_list(models) ->
        case decode_models(models) do
          {:ok, response} -> {:ok, %{response | raw: body}}
          error -> error
        end

      other ->
        {:error, Error.response_validation("models", other)}
    end
  end

  def decode(body), do: {:error, Error.response_validation("response", body)}

  @spec request_id!(t()) :: String.t()
  def request_id!(%__MODULE__{request_id: request_id}) when is_binary(request_id), do: request_id

  def request_id!(%__MODULE__{}) do
    raise Error.configuration("The response did not include a request ID")
  end

  @spec raw_http_response!(t()) :: Pristine.Response.t()
  def raw_http_response!(%__MODULE__{raw_http_response: %Pristine.Response{} = response}),
    do: response

  def raw_http_response!(%__MODULE__{}) do
    raise Error.configuration("The response was not created from a raw HTTP response")
  end

  defp decode_models(models) do
    models
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {raw, index}, {:ok, acc} ->
      case decode_model(raw, index) do
        {:ok, model} -> {:cont, {:ok, [model | acc]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, reversed} -> {:ok, %__MODULE__{models: Enum.reverse(reversed)}}
      error -> error
    end
  end

  defp decode_model(raw, index) when is_map(raw) do
    with {:ok, name} <- string_field(raw, "name", index),
         {:ok, description} <- string_field(raw, "description", index),
         {:ok, release_date} <- string_field(raw, "release_date", index) do
      {:ok, %ModelMetadata{name: name, description: description, release_date: release_date}}
    end
  end

  defp decode_model(raw, index),
    do: {:error, Error.response_validation("models[#{index}]", raw)}

  defp string_field(map, key, index) do
    value = Map.get(map, key) || Map.get(map, known_atom_key(key))

    if is_binary(value),
      do: {:ok, value},
      else: {:error, Error.response_validation("models[#{index}].#{key}", map)}
  end

  defp known_atom_key("name"), do: :name
  defp known_atom_key("description"), do: :description
  defp known_atom_key("release_date"), do: :release_date
end
