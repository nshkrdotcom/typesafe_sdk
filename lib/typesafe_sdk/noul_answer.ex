defmodule TypeSafeSDK.NoulAnswer do
  @moduledoc "A yes/no answer represented as the probability of true."
  @enforce_keys [:noul]
  defstruct [:noul]
  @type t :: %__MODULE__{noul: number()}
end
