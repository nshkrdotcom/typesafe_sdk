defmodule TypeSafeSDK.JSON do
  @moduledoc """
  JSON normalization for the semantic API, with collision detection and bounded nesting.

  Objects accept atom/string keys, but values must be JSON values. Arbitrary structs,
  PIDs and functions are rejected. Nothing received from the service is turned into atoms.
  """

  alias TypeSafeSDK.Error
  @max_depth 64

  @spec normalize(term(), [String.t()]) :: {:ok, term()} | {:error, Error.t()}
  def normalize(value, path \\ []), do: normalize(value, path, 0)

  @doc false
  def keyed_pairs(value, path, opts \\ []) do
    nonempty = Keyword.get(opts, :nonempty, true)

    with {:ok, pairs} <- pairs(value, path),
         {:ok, checked} <- check_pairs(pairs, path, nonempty) do
      if is_map(value), do: {:ok, Enum.sort_by(checked, &wire_key(elem(&1, 0)))}, else: {:ok, checked}
    end
  end

  @doc false
  def wire_key(key) when is_binary(key), do: key
  def wire_key(key) when is_atom(key), do: Atom.to_string(key)

  @doc false
  def description(nil, _path), do: {:ok, nil}
  def description(value, path) when is_binary(value) do
    if String.valid?(value) and String.trim(value) != "",
      do: {:ok, value},
      else: invalid(path, "must be a nonblank UTF-8 description")
  end
  def description(value, path) when is_map(value) or is_list(value), do: normalize(value, path)
  def description(_value, path), do: invalid(path, "must be a string, JSON object, array, or nil")

  @doc false
  def ordered(value) when is_map(value) and not is_struct(value) do
    value
    |> Enum.sort_by(fn {key, _} -> wire_key(key) end)
    |> Enum.map(fn {key, item} -> {wire_key(key), ordered(item)} end)
    |> Jason.OrderedObject.new()
  end
  def ordered(value) when is_list(value), do: Enum.map(value, &ordered/1)
  def ordered(value), do: value

  defp normalize(_value, path, depth) when depth > @max_depth,
    do: invalid(path, "JSON nesting exceeds #{@max_depth} levels")
  defp normalize(value, _path, _depth) when is_nil(value) or is_boolean(value) or is_integer(value),
    do: {:ok, value}
  defp normalize(value, path, _depth) when is_float(value) do
    if abs(value) <= 1.7976931348623157e308, do: {:ok, value}, else: invalid(path, "must be a finite JSON number")
  end
  defp normalize(value, path, _depth) when is_binary(value) do
    if String.valid?(value), do: {:ok, value}, else: invalid(path, "must be valid UTF-8")
  end
  defp normalize(value, path, depth) when is_list(value),
    do: normalize_list(value, path, depth, 0, [])
  defp normalize(value, path, depth) when is_map(value) and not is_struct(value) do
    with {:ok, pairs} <- keyed_pairs(value, path, nonempty: false) do
      Enum.reduce_while(pairs, {:ok, %{}}, fn {key, item}, {:ok, acc} ->
        key = wire_key(key)
        case normalize(item, path ++ [key], depth + 1) do
          {:ok, normalized} -> {:cont, {:ok, Map.put(acc, key, normalized)}}
          error -> {:halt, error}
        end
      end)
    end
  end
  defp normalize(_value, path, _depth), do: invalid(path, "is not a JSON value")

  defp normalize_list([], _path, _depth, _index, acc), do: {:ok, Enum.reverse(acc)}
  defp normalize_list([item | rest], path, depth, index, acc) do
    with {:ok, normalized} <- normalize(item, path ++ [Integer.to_string(index)], depth + 1) do
      normalize_list(rest, path, depth, index + 1, [normalized | acc])
    end
  end
  defp normalize_list(_, path, _depth, index, _acc),
    do: invalid(path ++ [Integer.to_string(index)], "JSON arrays must be proper lists")

  defp pairs(value, _path) when is_map(value) and not is_struct(value), do: {:ok, Enum.to_list(value)}
  defp pairs(value, path) when is_list(value) do
    _length = length(value)
    {:ok, value}
  rescue
    ArgumentError -> invalid(path, "key/value pairs must be a proper list")
  end
  defp pairs(_value, path), do: invalid(path, "must be a map or list of key/value pairs")

  defp check_pairs(pairs, path, nonempty) do
    Enum.reduce_while(pairs, {:ok, [], MapSet.new()}, fn
      {key, value}, {:ok, acc, seen} when is_binary(key) or (is_atom(key) and not is_nil(key)) ->
        wire = wire_key(key)
        cond do
          not String.valid?(wire) or (nonempty and String.trim(wire) == "") ->
            {:halt, invalid(path, "keys must be nonblank UTF-8 strings or atoms")}
          MapSet.member?(seen, wire) ->
            {:halt, invalid(path ++ [wire], "duplicate key after JSON normalization")}
          true -> {:cont, {:ok, [{key, value} | acc], MapSet.put(seen, wire)}}
        end
      _, _ -> {:halt, invalid(path, "expected atom/string key and value pairs")}
    end)
    |> case do
      {:ok, acc, _seen} -> {:ok, Enum.reverse(acc)}
      error -> error
    end
  end

  defp invalid(path, reason), do: {:error, Error.invalid_request(path, reason)}
end
