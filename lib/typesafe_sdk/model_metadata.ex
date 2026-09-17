defmodule TypeSafeSDK.ModelMetadata do
  @moduledoc "Metadata for one TypeSafe model."
  @enforce_keys [:name, :description, :release_date]
  defstruct [:name, :description, :release_date]
  @type t :: %__MODULE__{name: String.t(), description: String.t(), release_date: String.t()}
end
