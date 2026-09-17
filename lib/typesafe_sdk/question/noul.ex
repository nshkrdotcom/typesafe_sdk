defmodule TypeSafeSDK.Question.Noul do
  @moduledoc """
  Strict semantic yes/no question. `new/2` returns a tuple; `new!/2` raises.

      iex> {:ok, q} = TypeSafeSDK.Question.Noul.new("Urgent?", true: "Time-sensitive")
      iex> q.criteria
      [{true, "Time-sensitive"}]

  Options: `:true`, `:false`, or explicit `:criteria`; plus protected `:extra`.
  Do not combine explicit criteria with the true/false shorthand.
  """
  alias TypeSafeSDK.Question.Validation
  defstruct instructions: nil, criteria: nil, extra: %{}
  @type t :: %__MODULE__{instructions: term(), criteria: list() | nil, extra: map()}

  @spec new(term(), keyword()) :: {:ok, t()} | {:error, TypeSafeSDK.Error.t()}
  def new(instructions, opts \\ []) do
    with :ok <- Validation.options(opts, [true, false, :criteria, :extra]),
         :ok <- criteria_options(opts) do
      criteria = Keyword.get(opts, :criteria, Keyword.take(opts, [true, false]))

      q = %__MODULE__{
        instructions: instructions,
        criteria: criteria,
        extra: Keyword.get(opts, :extra, %{})
      }

      Validation.constructor(q)
    end
  end

  @spec new!(term(), keyword()) :: t()
  def new!(instructions, opts \\ []), do: Validation.unwrap!(new(instructions, opts))

  defp criteria_options(opts) do
    if Keyword.has_key?(opts, :criteria) and
         (Keyword.has_key?(opts, true) or Keyword.has_key?(opts, false)),
       do:
         {:error,
          TypeSafeSDK.Error.invalid_request(
            ["criteria"],
            "cannot combine criteria with true/false options"
          )},
       else: :ok
  end
end
