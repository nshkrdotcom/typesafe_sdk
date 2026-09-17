defmodule TypeSafeSDK.Prepared do
  @moduledoc """
  A validated, immutable semantic question contract.

  Preparation caches the exact wire fragment, retains finite caller-key metadata,
  and computes a versioned semantic fingerprint. Composition functions rebuild
  the value through the normal validation path, so ordering and request-relative
  invariants are never bypassed.
  """

  alias TypeSafeSDK.{Error, JSON}
  alias TypeSafeSDK.Question.Validation

  @fingerprint_namespace "typesafe-prepared-v1:"

  @enforce_keys [
    :encoded,
    :json,
    :definitions,
    :keys,
    :ordered_keys,
    :questions,
    :count,
    :fingerprint
  ]
  defstruct [
    :encoded,
    :json,
    :definitions,
    :keys,
    :ordered_keys,
    :questions,
    :count,
    :fingerprint
  ]

  @type caller_key :: atom() | String.t()
  @type t :: %__MODULE__{
          encoded: struct(),
          json: binary(),
          definitions: map(),
          keys: %{String.t() => caller_key()},
          ordered_keys: [caller_key()],
          questions: [{caller_key(), term()}],
          count: pos_integer(),
          fingerprint: String.t()
        }

  @spec new(t() | map() | list()) :: {:ok, t()} | {:error, Error.t()}
  def new(%__MODULE__{} = prepared), do: {:ok, prepared}

  def new(questions) do
    with {:ok, pairs} <- JSON.keyed_pairs(questions, ["questions"]),
         :ok <- nonempty(pairs),
         {:ok, definitions} <- compile(pairs) do
      wire =
        Enum.map(pairs, fn {key, _question} ->
          wire_key = JSON.wire_key(key)
          {wire_key, definitions[wire_key].wire}
        end)

      json = wire |> Jason.OrderedObject.new() |> Jason.encode!()
      fingerprint = fingerprint_for(pairs, definitions)

      {:ok,
       %__MODULE__{
         encoded: Jason.Fragment.new(json),
         json: json,
         definitions: definitions,
         keys: Map.new(pairs, fn {key, _} -> {JSON.wire_key(key), key} end),
         ordered_keys: Enum.map(pairs, &elem(&1, 0)),
         questions: pairs,
         count: length(pairs),
         fingerprint: fingerprint
       }}
    end
  end

  @spec new!(t() | map() | list()) :: t()
  def new!(questions), do: Validation.unwrap!(new(questions))

  @doc "Return caller keys in execution/wire order."
  @spec keys(t()) :: [caller_key()]
  def keys(%__MODULE__{ordered_keys: value}), do: value

  @doc "Return the versioned deterministic semantic-contract fingerprint."
  @spec fingerprint(t()) :: String.t()
  def fingerprint(%__MODULE__{fingerprint: value}), do: value

  @doc "Replace a question without moving it, or append a new key."
  @spec put(t(), caller_key(), term()) :: {:ok, t()} | {:error, Error.t()}
  def put(%__MODULE__{} = prepared, key, question)
      when is_binary(key) or (is_atom(key) and not is_nil(key)) do
    wire_key = JSON.wire_key(key)

    pairs =
      case Enum.split_while(prepared.questions, fn {existing, _} ->
             JSON.wire_key(existing) != wire_key
           end) do
        {left, [{existing_key, _old} | right]} -> left ++ [{existing_key, question} | right]
        {_all, []} -> prepared.questions ++ [{key, question}]
      end

    new(pairs)
  end

  def put(%__MODULE__{}, _key, _question),
    do: {:error, Error.invalid_request(["questions"], "invalid question key")}

  @doc "Delete one key and revalidate the resulting Prepared value."
  @spec delete(t(), caller_key()) :: {:ok, t()} | {:error, Error.t()}
  def delete(%__MODULE__{} = prepared, key)
      when is_binary(key) or (is_atom(key) and not is_nil(key)) do
    wire_key = JSON.wire_key(key)
    new(Enum.reject(prepared.questions, fn {existing, _} -> JSON.wire_key(existing) == wire_key end))
  end

  def delete(%__MODULE__{}, _key),
    do: {:error, Error.invalid_request(["questions"], "invalid question key")}

  @doc "Take selected keys while preserving their source execution order."
  @spec take(t(), Enumerable.t()) :: {:ok, t()} | {:error, Error.t()}
  def take(%__MODULE__{} = prepared, requested) do
    with {:ok, requested_wire} <- requested_wire_keys(requested) do
      prepared.questions
      |> Enum.filter(fn {key, _} -> MapSet.member?(requested_wire, JSON.wire_key(key)) end)
      |> new()
    end
  rescue
    Protocol.UndefinedError ->
      {:error, Error.invalid_request(["questions"], "take keys must be enumerable")}
  end

  @doc "Right-biased merge preserving duplicate positions from the left."
  @spec merge(t(), t()) :: {:ok, t()} | {:error, Error.t()}
  def merge(%__MODULE__{} = left, %__MODULE__{} = right) do
    merged =
      Enum.reduce(right.questions, left.questions, fn {right_key, right_question}, acc ->
        right_wire = JSON.wire_key(right_key)

        case Enum.split_while(acc, fn {left_key, _} -> JSON.wire_key(left_key) != right_wire end) do
          {before, [{left_key, _old} | after_pairs]} ->
            before ++ [{left_key, right_question} | after_pairs]

          {_before, []} ->
            acc ++ [{right_key, right_question}]
        end
      end)

    new(merged)
  end

  @doc false
  @spec encoded(t()) :: struct()
  def encoded(%__MODULE__{encoded: value}), do: value

  @doc false
  @spec definitions(t()) :: map()
  def definitions(%__MODULE__{definitions: value}), do: value

  @doc false
  @spec count(t()) :: pos_integer()
  def count(%__MODULE__{count: value}), do: value

  @doc false
  @spec wire_keys(t()) :: [String.t()]
  def wire_keys(%__MODULE__{ordered_keys: keys}), do: Enum.map(keys, &JSON.wire_key/1)

  @doc false
  @spec caller_key(t(), String.t()) :: {:ok, caller_key()} | :error
  def caller_key(%__MODULE__{keys: key_map}, wire_key), do: Map.fetch(key_map, wire_key)

  defp requested_wire_keys(requested) do
    Enum.reduce_while(requested, {:ok, MapSet.new()}, fn
      key, {:ok, acc} when is_binary(key) or (is_atom(key) and not is_nil(key)) ->
        {:cont, {:ok, MapSet.put(acc, JSON.wire_key(key))}}

      _key, _acc ->
        {:halt, {:error, Error.invalid_request(["questions"], "invalid take key")}}
    end)
  end

  defp nonempty([]),
    do: {:error, Error.invalid_request(["questions"], "at least one question is required")}

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

  defp fingerprint_for(pairs, definitions) do
    canonical =
      Enum.map(pairs, fn {caller_key, _question} ->
        wire_key = JSON.wire_key(caller_key)
        [wire_key, canonical_definition(Map.fetch!(definitions, wire_key))]
      end)
      |> Jason.encode!()

    digest = :crypto.hash(:sha256, canonical) |> Base.encode16(case: :lower)
    @fingerprint_namespace <> digest
  end

  defp canonical_definition(definition) do
    base = definition.wire |> Map.drop(["criteria"]) |> canonicalize()

    criteria =
      case definition.type do
        "choice" ->
          definition.criteria
          |> Enum.map(fn {key, description} -> [JSON.wire_key(key), canonicalize(description)] end)

        "score" ->
          Enum.map(definition.levels, fn level -> canonicalize(level.wire) end)

        "noul" ->
          case Map.get(definition, :criteria) do
            nil -> nil
            pairs ->
              pairs
              |> Enum.map(fn {key, description} -> [JSON.wire_key(key), canonicalize(description)] end)
              |> Enum.sort_by(&hd/1)
          end

        _future ->
          definition.wire |> Map.get("criteria") |> canonicalize()
      end

    Jason.OrderedObject.new([
      {"base", base},
      {"criteria", criteria}
    ])
  end

  defp canonicalize(value) when is_map(value) and not is_struct(value) do
    value
    |> Enum.map(fn {key, nested} -> {to_string(key), canonicalize(nested)} end)
    |> Enum.sort_by(&elem(&1, 0))
    |> Jason.OrderedObject.new()
  end

  defp canonicalize(value) when is_list(value), do: Enum.map(value, &canonicalize/1)
  defp canonicalize(value), do: value
end
