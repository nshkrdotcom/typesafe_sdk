defmodule TypeSafeSDK.Answer.Noul do
  @moduledoc "Noul decision helpers. The threshold is application policy, not a safety guarantee."
  alias TypeSafeSDK.NoulAnswer

  @doc "Compare probability of true with a threshold (default 0.5)."
  @spec yes?(NoulAnswer.t(), number()) :: boolean()
  def yes?(answer, threshold \\ 0.5)
  def yes?(%NoulAnswer{noul: p}, threshold)
      when is_number(threshold) and threshold >= 0 and threshold <= 1,
      do: p >= threshold
  def yes?(%NoulAnswer{}, _), do: raise(ArgumentError, "threshold must be in [0, 1]")

  @doc "Return max(p, 1-p), a derived certainty measure, not provider confidence."
  @spec confidence(NoulAnswer.t()) :: number()
  def confidence(%NoulAnswer{noul: p}), do: max(p, 1 - p)
end
