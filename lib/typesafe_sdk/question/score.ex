defmodule TypeSafeSDK.Question.Score do
  @moduledoc """
  Strict Score on 2..10 ordered levels.

  A level is a description or `{label, description}`. The pair is sent as a
  structured object and its label is restored on the semantic answer. Unknown
  JSON properties may be supplied through `:extra` without overriding core fields.
  """
  alias TypeSafeSDK.Question.Validation
  @enforce_keys [:levels]
  defstruct [:levels, instructions: nil, extra: %{}]
  @type t :: %__MODULE__{instructions: term(), levels: list(), extra: map()}

  @spec new(term(), list(), keyword()) :: {:ok, t()} | {:error, TypeSafeSDK.Error.t()}
  def new(instructions, levels, opts \\ []) do
    with :ok <- Validation.options(opts, [:extra]) do
      Validation.constructor(%__MODULE__{
        instructions: instructions,
        levels: levels,
        extra: Keyword.get(opts, :extra, %{})
      })
    end
  end

  @spec new!(term(), list(), keyword()) :: t()
  def new!(instructions, levels, opts \\ []),
    do: Validation.unwrap!(new(instructions, levels, opts))
end
