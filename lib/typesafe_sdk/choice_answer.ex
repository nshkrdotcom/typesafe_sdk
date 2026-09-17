defmodule TypeSafeSDK.ChoiceAnswer do
  @moduledoc "A selected option, independent confidence and complete option distribution."
  @enforce_keys [:choice, :confidence, :probabilities]
  defstruct [:choice, :confidence, :probabilities, :id, :raw, option_order: []]
  @type t :: %__MODULE__{choice: atom() | String.t(), confidence: number(), probabilities: map(),
          id: atom() | String.t() | nil, raw: map() | nil, option_order: list()}
end
