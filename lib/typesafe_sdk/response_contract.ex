defmodule TypeSafeSDK.ResponseContract do
  @moduledoc false

  alias TypeSafeSDK.{Error, Prepared, SystemOneResponse}

  @defaults %{on_unknown_answer: :preserve, allowed_models: nil}
  @keys Map.keys(@defaults)

  @type t :: %{
          required(:on_unknown_answer) => :preserve | :error,
          required(:allowed_models) => [String.t()] | nil
        }

  @spec normalize(nil | keyword() | map()) :: {:ok, t()} | {:error, Error.t()}
  def normalize(nil), do: {:ok, @defaults}

  def normalize(value) when is_list(value) do
    cond do
      not Keyword.keyword?(value) ->
        invalid("must be a keyword list or map")

      length(Keyword.keys(value)) != length(Enum.uniq(Keyword.keys(value))) ->
        invalid("duplicate response contract options are not allowed")

      true ->
        normalize(Map.new(value))
    end
  end

  def normalize(value) when is_map(value) and not is_struct(value) do
    unknown = Map.keys(value) -- @keys

    with [] <- unknown,
         contract <- Map.merge(@defaults, value),
         :ok <- unknown_policy(contract.on_unknown_answer),
         {:ok, models} <- allowed_models(contract.allowed_models) do
      {:ok, %{contract | allowed_models: models}}
    else
      [_ | _] -> invalid("unknown response contract option")
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  def normalize(_value), do: invalid("must be a keyword list, map, or nil")

  @spec merge(t(), nil | keyword() | map()) :: {:ok, t()} | {:error, Error.t()}
  def merge(%{} = client_default, override) do
    case override do
      nil -> {:ok, client_default}
      value when is_list(value) -> merge_map(client_default, value)
      value when is_map(value) and not is_struct(value) -> merge_map(client_default, value)
      _ -> invalid("must be a keyword list, map, or nil")
    end
  end

  @spec validate(SystemOneResponse.t(), Prepared.t(), t()) :: :ok | {:error, Error.t()}
  def validate(%SystemOneResponse{} = response, %Prepared{} = prepared, contract) do
    result =
      with :ok <- validate_model(response.model, contract.allowed_models) do
        validate_unknown_answers(response, prepared, contract.on_unknown_answer)
      end

    case result do
      :ok -> :ok
      {:error, %Error{} = error} -> {:error, %{error | request_id: response.request_id}}
    end
  end

  defp merge_map(client_default, value) when is_list(value) do
    if Keyword.keyword?(value),
      do: merge_map(client_default, Map.new(value)),
      else: invalid("must be a keyword list")
  end

  defp merge_map(client_default, value) when is_map(value) do
    normalize(Map.merge(client_default, value))
  end

  defp unknown_policy(value) when value in [:preserve, :error], do: :ok
  defp unknown_policy(_), do: invalid("on_unknown_answer must be :preserve or :error")

  defp allowed_models(nil), do: {:ok, nil}

  defp allowed_models(models) when is_list(models) do
    if models != [] and Enum.all?(models, &valid_model?/1) do
      {:ok, Enum.uniq(models)}
    else
      invalid("allowed_models must be nil or a non-empty list of nonblank model IDs")
    end
  end

  defp allowed_models(_), do: invalid("allowed_models must be nil or a list of model IDs")

  defp valid_model?(model),
    do: is_binary(model) and String.valid?(model) and String.trim(model) != ""

  defp validate_model(_model, nil), do: :ok

  defp validate_model(model, allowed) when is_binary(model) do
    if model in allowed,
      do: :ok,
      else:
        {:error,
         Error.response_contract(:model_not_allowed, %{
           model: bounded(model),
           allowed_model_count: length(allowed)
         })}
  end

  defp validate_model(_model, allowed),
    do: {:error, Error.response_contract(:model_missing, %{allowed_model_count: length(allowed)})}

  defp validate_unknown_answers(_response, _prepared, :preserve), do: :ok

  defp validate_unknown_answers(response, prepared, :error) do
    requested = MapSet.new(Prepared.wire_keys(prepared))

    (Map.keys(response.answers) ++ Map.keys(response.unknown_answers))
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.find(fn key -> not MapSet.member?(requested, key) end)
    |> case do
      nil -> :ok
      key -> {:error, Error.response_contract(:unknown_answer, %{answer_key: bounded(key)})}
    end
  end

  defp bounded(value) when is_binary(value) and byte_size(value) <= 128, do: value
  defp bounded(value) when is_binary(value), do: String.slice(value, 0, 128)
  defp bounded(value), do: value |> to_string() |> bounded()

  defp invalid(reason),
    do: {:error, Error.invalid_request(["options", "response_contract"], reason)}
end
