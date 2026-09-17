defmodule TypeSafeSDK.Question.Choice do
  @moduledoc """
  Strict Choice with 2..255 alternatives and finite caller-key restoration.

  Pair lists preserve order. Maps are sorted by wire key, not assumed to retain
  insertion order. `:extra` permits future fields except type/instructions/criteria.
  """
  alias TypeSafeSDK.Question.Validation
  @enforce_keys [:criteria]
  defstruct [:criteria, instructions: nil, extra: %{}]
  @type t :: %__MODULE__{instructions: term(), criteria: list(), extra: map()}

  @spec new(term(), map() | list(), keyword()) :: {:ok, t()} | {:error, TypeSafeSDK.Error.t()}
  def new(instructions, criteria, opts \\ []) do
    with :ok <- Validation.options(opts, [:extra]) do
      Validation.constructor(%__MODULE__{
        instructions: instructions,
        criteria: criteria,
        extra: Keyword.get(opts, :extra, %{})
      })
    end
  end

  @spec new!(term(), map() | list(), keyword()) :: t()
  def new!(instructions, criteria, opts \\ []),
    do: Validation.unwrap!(new(instructions, criteria, opts))
end
