defmodule TypeSafeSDK.NoulCriteria do
  @moduledoc """
  Type contract for optional descriptions of the true and false Noul outcomes.

  The API permits additional JSON-compatible keys, matching the Python SDK's
  forward-compatible `NoulCriteria` typed dictionary.
  """

  @type t :: %{optional(String.t() | atom()) => term() | nil}
end
