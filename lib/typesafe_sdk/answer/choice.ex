defmodule TypeSafeSDK.Answer.Choice do
  @moduledoc "Read a Choice distribution without imposing routing policy."
  alias TypeSafeSDK.ChoiceAnswer

  @doc "Descending probabilities; ties follow caller order, then deterministic key order."
  @spec ranked(ChoiceAnswer.t()) :: [{atom() | String.t(), number()}]
  def ranked(%ChoiceAnswer{probabilities: probabilities, option_order: order}) do
    positions = order |> Enum.with_index() |> Map.new()
    Enum.sort_by(probabilities, fn {key, probability} ->
      {-probability, Map.get(positions, key, map_size(positions)), to_string(key)}
    end)
  end

  @doc "Difference between the top two probabilities (0 for an empty distribution)."
  @spec margin(ChoiceAnswer.t()) :: number()
  def margin(answer) do
    case ranked(answer) do
      [{_, first}, {_, second} | _] -> first - second
      [{_, first}] -> first
      [] -> 0.0
    end
  end
end
