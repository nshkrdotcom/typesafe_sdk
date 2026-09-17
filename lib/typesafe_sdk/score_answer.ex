defmodule TypeSafeSDK.ScoreAnswer do
  @moduledoc "An expected score, not necessarily the most probable level."
  @enforce_keys [:score, :confidence, :legend, :probabilities]
  defstruct [:score, :confidence, :legend, :probabilities, :id, :raw, :level, :label, :description, levels: [], rubric: []]
  @type t :: %__MODULE__{score: number(), confidence: number(), legend: map(), probabilities: map(),
          id: atom() | String.t() | nil, raw: map() | nil, level: integer() | nil,
          label: term(), description: term(), levels: list(), rubric: list()}
end
