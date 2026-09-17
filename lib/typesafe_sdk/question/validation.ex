defmodule TypeSafeSDK.Question.Validation do
  @moduledoc false
  alias TypeSafeSDK.{Error, JSON}
  alias TypeSafeSDK.Question.{Choice, Noul, Score}
  @reserved ~w(type instructions criteria)

  def constructor(question) do
    with {:ok, definition} <- compile(question, []) do
      {:ok, normalize_constructor(question, definition)}
    end
  end

  def unwrap!({:ok, value}), do: value
  def unwrap!({:error, error}), do: raise(error)

  def options(opts, allowed) do
    cond do
      not is_list(opts) or not Keyword.keyword?(opts) ->
        invalid(["options"], "must be a keyword list")
      length(Keyword.keys(opts)) != length(Enum.uniq(Keyword.keys(opts))) ->
        invalid(["options"], "duplicate options are not allowed")
      true ->
        case Keyword.keys(opts) -- allowed do
          [] -> :ok
          [unknown | _] -> invalid(["options", Atom.to_string(unknown)], "unknown option")
        end
    end
  end

  def compile(question, path) do
    with {:ok, type, instructions, criteria, extra} <- fields(question, path),
         {:ok, instructions} <- JSON.description(instructions, path ++ ["instructions"]),
         {:ok, extra} <- extras(extra, path ++ ["extra"]),
         {:ok, definition} <- criteria(type, criteria, path ++ ["criteria"]) do
      wire = extra |> Map.put("type", type) |> put_non_nil("instructions", instructions)
      wire = if Map.has_key?(definition, :wire_criteria),
        do: Map.put(wire, "criteria", definition.wire_criteria), else: wire
      {:ok, Map.merge(definition, %{type: type, wire: wire})}
    end
  end

  defp fields(%Noul{} = q, _), do: {:ok, "noul", q.instructions, q.criteria, q.extra}
  defp fields(%Choice{} = q, _), do: {:ok, "choice", q.instructions, q.criteria, q.extra}
  defp fields(%Score{} = q, _), do: {:ok, "score", q.instructions, q.levels, q.extra}
  defp fields(%TypeSafeSDK.Noul{} = q, _), do: {:ok, "noul", q.instructions, q.criteria, %{}}
  defp fields(%TypeSafeSDK.Choice{} = q, _), do: {:ok, "choice", q.instructions, q.criteria, %{}}
  defp fields(%TypeSafeSDK.Score{} = q, _), do: {:ok, "score", q.instructions, q.criteria, %{}}
  defp fields(q, path) when is_map(q) and not is_struct(q) do
    with {:ok, pairs} <- JSON.keyed_pairs(q, path) do
      map = Map.new(pairs, fn {key, value} -> {JSON.wire_key(key), value} end)
      case map["type"] do
        type when is_binary(type) ->
          if String.valid?(type) and String.trim(type) != "" do
            {:ok, type, map["instructions"], map["criteria"], Map.drop(map, @reserved)}
          else
            invalid(path ++ ["type"], "must be a nonblank UTF-8 string")
          end
        _ -> invalid(path ++ ["type"], "must be a nonblank string")
      end
    end
  end
  defp fields(_, path), do: invalid(path, "must be a question struct or raw question map")

  defp extras(extra, path) when is_map(extra) and not is_struct(extra) do
    with {:ok, normalized} <- JSON.normalize(extra, path) do
      case Enum.find(@reserved, &Map.has_key?(normalized, &1)) do
        nil -> {:ok, normalized}
        key -> invalid(path ++ [key], "cannot override a canonical question field")
      end
    end
  end
  defp extras(_, path), do: invalid(path, "must be a JSON object")

  defp criteria("noul", value, _path) when value in [nil, []], do: {:ok, %{criteria: nil}}
  defp criteria("noul", value, path) do
    with {:ok, pairs} <- JSON.keyed_pairs(value, path),
         :ok <- noul_keys(pairs, path),
         {:ok, pairs} <- descriptions(pairs, path) do
      {:ok, %{criteria: pairs, wire_criteria: Map.new(pairs, fn {key, v} -> {JSON.wire_key(key), v} end)}}
    end
  end
  defp criteria("choice", value, path) do
    with {:ok, pairs} <- JSON.keyed_pairs(value, path),
         :ok <- count(pairs, 2, 255, path),
         {:ok, pairs} <- descriptions(pairs, path) do
      keys = Map.new(pairs, fn {key, _} -> {JSON.wire_key(key), key} end)
      wire = Enum.map(pairs, fn {key, v} -> {JSON.wire_key(key), v} end)
      {:ok, %{criteria: pairs, option_keys: keys, option_order: Enum.map(pairs, &elem(&1, 0)),
        wire_criteria: Jason.OrderedObject.new(wire)}}
    end
  end
  defp criteria("score", value, path) when is_list(value) do
    with :ok <- count(value, 2, 10, path),
         {:ok, levels} <- levels(value, path) do
      {:ok, %{levels: levels, wire_criteria: Enum.map(levels, & &1.wire)}}
    end
  end
  defp criteria("score", _, path), do: invalid(path, "must be a list of 2..10 levels")
  defp criteria(_future, nil, _path), do: {:ok, %{}}
  defp criteria(_future, value, path) do
    with {:ok, normalized} <- JSON.normalize(value, path), do: {:ok, %{wire_criteria: normalized}}
  end

  defp noul_keys(pairs, path) do
    case Enum.find(pairs, fn {key, _} -> JSON.wire_key(key) not in ["true", "false"] end) do
      nil -> :ok
      {key, _} -> invalid(path ++ [JSON.wire_key(key)], "Noul criteria keys must be true or false")
    end
  end

  defp descriptions(pairs, path) do
    Enum.reduce_while(pairs, {:ok, []}, fn {key, value}, {:ok, acc} ->
      case JSON.description(value, path ++ [JSON.wire_key(key)]) do
        {:ok, normalized} -> {:cont, {:ok, [{key, normalized} | acc]}}
        error -> {:halt, error}
      end
    end)
    |> reverse_ok()
  end

  defp levels(values, path) do
    values |> Enum.with_index() |> Enum.reduce_while({:ok, []}, fn {value, index}, {:ok, acc} ->
      case level(value, index, path ++ [Integer.to_string(index)]) do
        {:ok, level} -> {:cont, {:ok, [level | acc]}}
        error -> {:halt, error}
      end
    end) |> reverse_ok()
  end

  defp level({label, description}, index, path) when is_binary(label) do
    with {:ok, label} <- JSON.description(label, path ++ ["label"]),
         {:ok, description} <- JSON.description(description, path ++ ["description"]),
         :ok <- present(description, path ++ ["description"]) do
      {:ok, %{index: index, label: label, description: description,
        wire: %{"label" => label, "description" => description}}}
    end
  end
  defp level(value, index, path) do
    with {:ok, normalized} <- JSON.description(value, path),
         :ok <- present(normalized, path) do
      label = cond do
        is_binary(normalized) -> normalized
        is_map(normalized) and is_binary(normalized["label"]) -> normalized["label"]
        true -> "Level #{index}"
      end
      description = if is_map(normalized), do: Map.get(normalized, "description", normalized), else: normalized
      {:ok, %{index: index, label: label, description: description, wire: normalized}}
    end
  end

  defp count(values, min, max, path) do
    if length(values) in min..max, do: :ok,
      else: invalid(path, "requires #{min}..#{max} entries", %{count: length(values), min: min, max: max})
  rescue
    ArgumentError -> invalid(path, "entries must be a proper list")
  end
  defp present(nil, path), do: invalid(path, "level description cannot be nil")
  defp present(_, _), do: :ok
  defp normalize_constructor(%Choice{} = q, d), do: %{q | criteria: d.criteria}
  defp normalize_constructor(%Noul{} = q, d), do: %{q | criteria: d.criteria}
  defp normalize_constructor(q, _), do: q
  defp put_non_nil(map, _key, nil), do: map
  defp put_non_nil(map, key, value), do: Map.put(map, key, value)
  defp reverse_ok({:ok, values}), do: {:ok, Enum.reverse(values)}
  defp reverse_ok(error), do: error
  defp invalid(path, reason, details \\ %{}), do: {:error, Error.invalid_request(path, reason, details)}
end
