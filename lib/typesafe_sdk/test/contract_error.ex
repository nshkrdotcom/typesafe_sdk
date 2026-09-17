defmodule TypeSafeSDK.Test.ContractError do
  @moduledoc "Raised when an explicit application test fixture contradicts the actual request."
  defexception [:message]
end
