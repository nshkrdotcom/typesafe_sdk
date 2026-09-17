defmodule TypeSafeSDK.Answer do
  @moduledoc "Uncertainty helpers with explicit application-owned policy thresholds."
  alias TypeSafeSDK.Answer.Noul
  alias TypeSafeSDK.{ChoiceAnswer, NoulAnswer, ScoreAnswer}
  alias TypeSafeSDK.Question.Validation

  @spec confidence(NoulAnswer.t() | ChoiceAnswer.t() | ScoreAnswer.t()) :: number()
  def confidence(%NoulAnswer{} = answer), do: Noul.confidence(answer)
  def confidence(%ChoiceAnswer{confidence: confidence}), do: confidence
  def confidence(%ScoreAnswer{confidence: confidence}), do: confidence

  defdelegate yes?(answer), to: Noul
  defdelegate yes?(answer, threshold), to: Noul

  @doc "Classify certainty using explicit `act:` and `review:` thresholds. No implicit policy."
  @spec gate(NoulAnswer.t() | ChoiceAnswer.t() | ScoreAnswer.t(), keyword()) ::
          :act | :review | :escalate
  def gate(answer, opts) do
    with :ok <- Validation.options(opts, [:act, :review]),
         {:ok, act} <- Keyword.fetch(opts, :act),
         {:ok, review} <- Keyword.fetch(opts, :review),
         true <- is_number(act) and is_number(review) and 0 <= review and review <= act and act <= 1 do
      value = confidence(answer)

      cond do
        value >= act -> :act
        value >= review -> :review
        true -> :escalate
      end
    else
      _ ->
        raise ArgumentError, "gate requires 0 <= review <= act <= 1, with both thresholds explicit"
    end
  end
end
