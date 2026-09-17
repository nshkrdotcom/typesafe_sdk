defmodule TypeSafeSDK.ChoiceAnswer do
  @moduledoc "A selected label with confidence and label probabilities."
  @enforce_keys [:choice, :confidence, :probabilities]
  defstruct [:choice, :confidence, :probabilities]

  @type t :: %__MODULE__{
          choice: String.t(),
          confidence: number(),
          probabilities: %{String.t() => number()}
        }
end
