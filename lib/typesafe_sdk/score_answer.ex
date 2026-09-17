defmodule TypeSafeSDK.ScoreAnswer do
  @moduledoc "An expected score with integer-keyed rubric and probabilities."
  @enforce_keys [:score, :confidence, :legend, :probabilities]
  defstruct [:score, :confidence, :legend, :probabilities]

  @type t :: %__MODULE__{
          score: number(),
          confidence: number(),
          legend: %{integer() => term()},
          probabilities: %{integer() => number()}
        }
end
