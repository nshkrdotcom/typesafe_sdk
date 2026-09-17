defmodule TypeSafeSDK.Usage do
  @moduledoc "Token counts returned by the API when available."
  defstruct input_tokens: nil, output_tokens: nil

  @type t :: %__MODULE__{
          input_tokens: non_neg_integer() | nil,
          output_tokens: non_neg_integer() | nil
        }
end
