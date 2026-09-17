defmodule TypeSafeSDK do
  @moduledoc """
  Elixir client for the TypeSafe AI API.

  Use `evaluate/4` for validated questions, caller-key preservation and enriched
  answers, or `system_one/4` for the existing wire-oriented parity interface.
  Both execute through the same generated operations and Pristine runtime.
  """

  alias TypeSafeSDK.{Client, Models, SystemOne}
  alias TypeSafeSDK.Question.Validation

  @version "0.3.0"

  @spec version() :: String.t()
  def version, do: @version

  @spec new_client(keyword()) :: Client.t()
  defdelegate new_client(opts \\ []), to: Client, as: :new

  @spec system_one(Client.t(), term(), map(), keyword()) ::
          {:ok, TypeSafeSDK.SystemOneResponse.t()} | {:error, term()}
  defdelegate system_one(client, state, questions, opts \\ []), to: SystemOne, as: :run

  @doc "Strict Noul constructor. Raises on invalid locally defined questions."
  defdelegate noul(instructions, opts \\ []), to: TypeSafeSDK.Question.Noul, as: :new!
  @doc "Strict ordered Choice constructor."
  defdelegate choice(instructions, criteria, opts \\ []), to: TypeSafeSDK.Question.Choice, as: :new!
  @doc "Strict ordered Score constructor."
  defdelegate score(instructions, levels, opts \\ []), to: TypeSafeSDK.Question.Score, as: :new!

  @doc "Validate and prepare questions once, returning a tuple."
  defdelegate prepare(questions), to: TypeSafeSDK.Prepared, as: :new
  @doc "Validate and prepare questions or raise."
  defdelegate prepare!(questions), to: TypeSafeSDK.Prepared, as: :new!

  @doc "Evaluate with caller-key restoration and request-relative answer validation."
  defdelegate evaluate(client, state, questions, opts \\ []), to: TypeSafeSDK.Evaluation, as: :run
  @doc "Evaluate or raise the normalized SDK error."
  def evaluate!(client, state, questions, opts \\ []),
    do: Validation.unwrap!(evaluate(client, state, questions, opts))

  @doc "Lazy, bounded evaluation. See `TypeSafeSDK.Batch`."
  defdelegate evaluate_stream(client, states, questions, opts \\ []),
    to: TypeSafeSDK.Batch,
    as: :stream

  @doc "Collect the bounded evaluation stream."
  defdelegate evaluate_many(client, states, questions, opts \\ []), to: TypeSafeSDK.Batch, as: :many

  @doc "Legacy wire-oriented system_one call, raising on error."
  def system_one!(client, state, questions, opts \\ []),
    do: Validation.unwrap!(system_one(client, state, questions, opts))

  @spec list_models(Client.t(), keyword()) ::
          {:ok, TypeSafeSDK.ListModelsResponse.t()} | {:error, term()}
  defdelegate list_models(client, opts \\ []), to: Models, as: :list
end
