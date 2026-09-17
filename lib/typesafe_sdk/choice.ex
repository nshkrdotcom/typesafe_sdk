defmodule TypeSafeSDK.Choice do
  @moduledoc """
  A question that selects one named alternative.

  Construction intentionally does not validate the runtime shape of `criteria`.
  This matches the Python SDK: structural schema validation belongs to the API,
  while the SDK only requires that a typed Choice carries the field.
  """

  @enforce_keys [:criteria]
  defstruct [:criteria, instructions: nil]
  @type t :: %__MODULE__{criteria: term(), instructions: term() | nil}

  @spec new(term(), keyword()) :: t()
  def new(criteria, opts \\ []) when is_list(opts) do
    %__MODULE__{criteria: criteria, instructions: Keyword.get(opts, :instructions)}
  end
end
