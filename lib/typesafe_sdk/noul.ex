defmodule TypeSafeSDK.Noul do
  @moduledoc "A yes/no question with optional instructions and true/false descriptions."
  defstruct instructions: nil, criteria: nil

  @type t :: %__MODULE__{
          instructions: term() | nil,
          criteria: TypeSafeSDK.NoulCriteria.t() | map() | nil
        }

  @spec new(keyword() | map()) :: t()
  def new(attrs \\ []) do
    attrs = if is_map(attrs), do: attrs, else: Map.new(attrs)
    struct!(__MODULE__, attrs)
  end
end
