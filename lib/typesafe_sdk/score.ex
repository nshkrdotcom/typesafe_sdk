defmodule TypeSafeSDK.Score do
  @moduledoc "A question that assigns a score from an ordered rubric."
  @enforce_keys [:criteria]
  defstruct [:criteria, instructions: nil]
  @type t :: %__MODULE__{criteria: list(), instructions: term() | nil}

  @spec new(list(), keyword()) :: t()
  def new(criteria, opts \\ []) when is_list(criteria) and is_list(opts) do
    %__MODULE__{criteria: criteria, instructions: Keyword.get(opts, :instructions)}
  end
end
