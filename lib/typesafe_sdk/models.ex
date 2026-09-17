defmodule TypeSafeSDK.Models do
  alias TypeSafeSDK.Generated.Models, as: GeneratedModels

  @moduledoc "Models API resource and pure catalog helpers."

  alias TypeSafeSDK.{Client, Error, ListModelsResponse, ModelMetadata}

  @spec list(Client.t(), keyword()) :: {:ok, ListModelsResponse.t()} | {:error, term()}
  def list(%Client{} = client, opts \\ []) when is_list(opts) do
    case GeneratedModels.list(client, %{}, opts) do
      {:ok, body} -> ListModelsResponse.decode(body)
      {:error, error} -> {:error, error}
    end
  end

  @doc "Find one model by exact identifier; no fuzzy or prefix matching is performed."
  @spec find([ModelMetadata.t()] | ListModelsResponse.t(), String.t()) ::
          {:ok, ModelMetadata.t()} | {:error, Error.t()}
  def find(models, identifier) when is_binary(identifier) do
    matches = models |> catalog() |> Enum.filter(&(&1.name == identifier))

    case matches do
      [model] ->
        {:ok, model}

      [] ->
        {:error, Error.model_lookup(:model_not_found, identifier)}

      many ->
        {:error, Error.model_lookup(:ambiguous_model, identifier, %{match_count: length(many)})}
    end
  end

  def find(_models, identifier),
    do: {:error, Error.model_lookup(:model_not_found, identifier, %{reason: :invalid_identifier})}

  @doc "Exact lookup that raises the SDK error on failure."
  @spec find!([ModelMetadata.t()] | ListModelsResponse.t(), String.t()) :: ModelMetadata.t()
  def find!(models, identifier) do
    case find(models, identifier) do
      {:ok, model} -> model
      {:error, error} -> raise error
    end
  end

  @doc """
  Select the objectively latest model by `release_date`.

  `selector` may be `:all`, an exact model name, a keyword/map of exact model
  fields, or a unary predicate. Invalid/missing release dates and ties fail
  closed instead of falling back to lexical or provider-return order.
  """
  @spec latest([ModelMetadata.t()] | ListModelsResponse.t(), term()) ::
          {:ok, ModelMetadata.t()} | {:error, Error.t()}
  def latest(models, selector) do
    selected = models |> catalog() |> select(selector)

    with {:ok, dated} <- objective_dates(selected) do
      unique_latest(dated)
    end
  end

  defp catalog(%ListModelsResponse{models: models}), do: models
  defp catalog(models) when is_list(models), do: Enum.filter(models, &match?(%ModelMetadata{}, &1))
  defp catalog(_), do: []

  defp select(models, :all), do: models

  defp select(models, identifier) when is_binary(identifier),
    do: Enum.filter(models, &(&1.name == identifier))

  defp select(models, fun) when is_function(fun, 1), do: Enum.filter(models, fun)

  defp select(models, selector) when is_list(selector) do
    if Keyword.keyword?(selector), do: select(models, Map.new(selector)), else: []
  end

  defp select(models, selector) when is_map(selector) and not is_struct(selector) do
    allowed = Map.take(selector, [:name, :description, :release_date])

    if map_size(allowed) == map_size(selector) do
      Enum.filter(models, &matches_fields?(&1, allowed))
    else
      []
    end
  end

  defp select(_models, _selector), do: []

  defp matches_fields?(model, fields) do
    Enum.all?(fields, fn {key, value} -> Map.get(model, key) == value end)
  end

  defp objective_dates([]), do: {:error, Error.model_lookup(:model_not_found, "<selector>")}

  defp objective_dates(models) do
    Enum.reduce_while(models, {:ok, []}, fn model, {:ok, acc} ->
      case parse_release_date(model.release_date) do
        {:ok, date} ->
          {:cont, {:ok, [{date, model} | acc]}}

        {:error, _} ->
          {:halt, {:error, Error.unordered_model_catalog(%{reason: :invalid_release_date})}}
      end
    end)
  end

  defp parse_release_date(value) when is_binary(value), do: Date.from_iso8601(value)
  defp parse_release_date(_), do: {:error, :invalid_release_date}

  defp unique_latest(dated) do
    latest_date =
      dated
      |> Enum.map(&elem(&1, 0))
      |> Enum.reduce(fn date, latest ->
        if Date.compare(date, latest) == :gt, do: date, else: latest
      end)

    latest = Enum.filter(dated, fn {date, _model} -> Date.compare(date, latest_date) == :eq end)

    case latest do
      [{_date, model}] ->
        {:ok, model}

      _ ->
        {:error, Error.unordered_model_catalog(%{reason: :release_date_tie, count: length(latest)})}
    end
  end
end
