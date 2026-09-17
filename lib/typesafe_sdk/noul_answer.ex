defmodule TypeSafeSDK.NoulAnswer do
  @moduledoc "A probability of true. Semantic evaluations also retain the caller ID and raw answer."
  @enforce_keys [:noul]
  defstruct [:noul, :id, :raw]
  @type t :: %__MODULE__{noul: number(), id: atom() | String.t() | nil, raw: map() | nil}
end
