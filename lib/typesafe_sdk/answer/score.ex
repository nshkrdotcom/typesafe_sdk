defmodule TypeSafeSDK.Answer.Score do
  @moduledoc "Score distributions, rounded expectations, modal levels and normalization."
  alias TypeSafeSDK.ScoreAnswer

  @spec ranked(ScoreAnswer.t()) :: [{integer(), number()}]
  def ranked(%ScoreAnswer{probabilities: probabilities}),
    do: Enum.sort_by(probabilities, fn {index, p} -> {-p, index} end)

  @doc "Rounded expected level and its caller label; this is NOT necessarily the modal level."
  @spec expected_level(ScoreAnswer.t()) :: {integer(), term()}
  def expected_level(%ScoreAnswer{score: score} = answer) do
    index = round(score)
    {index, label(answer, index)}
  end

  @doc "Most probable level and label. Ties choose the lowest index."
  @spec max_level(ScoreAnswer.t()) :: {integer(), term()} | nil
  def max_level(answer) do
    case ranked(answer) do
      [{index, _} | _] -> {index, label(answer, index)}
      [] -> nil
    end
  end

  @doc "Expected score / highest level index; a one-level legacy rubric yields 0.0."
  @spec normalized(ScoreAnswer.t()) :: number()
  def normalized(%ScoreAnswer{score: score, legend: legend}) do
    top = legend |> Map.keys() |> Enum.max(fn -> 0 end)
    if top > 0, do: score / top, else: 0.0
  end

  defp label(%ScoreAnswer{rubric: rubric, legend: legend}, index) do
    case Enum.find(rubric, &(&1.index == index)) do
      nil -> Map.get(legend, index)
      level -> level.label
    end
  end
end
