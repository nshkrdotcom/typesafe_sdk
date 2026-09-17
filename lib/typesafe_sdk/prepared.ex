defmodule TypeSafeSDK.Prepared do
  @moduledoc """
  A validated question set with wire encoding and finite caller-key metadata.

  Construct with `TypeSafeSDK.prepare/1` or `prepare!/1`; reuse across states.
  No HTTP call, dynamic atom creation, or process state is involved. Treat the
  fields as opaque: editing them bypasses preparation invariants.
  """
  alias TypeSafeSDK.{Error, JSON}
  alias TypeSafeSDK.Question.Validation
  @enforce_keys [:encoded, :json, :definitions, :keys, :count]
  defstruct [:encoded, :json, :definitions, :keys, :count]
  @opaque t :: %__MODULE__{encoded: struct(), json: binary(), definitions: map(), keys: map(), count: pos_integer()}

  @spec new(t() | map() | list()) :: {:ok, t()} | {:error, Error.t()}
  def new(%__MODULE__{} = prepared), do: {:ok, prepared}
  def new(questions) do
    with {:ok, pairs} <- JSON.keyed_pairs(questions, ["questions"]),
         :ok <- nonempty(pairs),
         {:ok, definitions} <- compile(pairs) do
      wire = Enum.map(pairs, fn {key, _} -> {JSON.wire_key(key), definitions[JSON.wire_key(key)].wire} end)
      json = wire |> Jason.OrderedObject.new() |> Jason.encode!()
      {:ok, %__MODULE__{encoded: Jason.Fragment.new(json), json: json, definitions: definitions,
        keys: Map.new(pairs, fn {key, _} -> {JSON.wire_key(key), key} end), count: length(pairs)}}
    end
  end

  @spec new!(t() | map() | list()) :: t()
  def new!(questions), do: Validation.unwrap!(new(questions))

  defp nonempty([]), do: {:error, Error.invalid_request(["questions"], "at least one question is required")}
  defp nonempty(_), do: :ok
  defp compile(pairs) do
    Enum.reduce_while(pairs, {:ok, %{}}, fn {key, question}, {:ok, acc} ->
      wire_key = JSON.wire_key(key)
      case Validation.compile(question, ["questions", wire_key]) do
        {:ok, definition} -> {:cont, {:ok, Map.put(acc, wire_key, definition)}}
        error -> {:halt, error}
      end
    end)
  end
end
