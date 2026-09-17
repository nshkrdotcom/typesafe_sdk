defmodule TypeSafeSDK.Generated.Client do
  @moduledoc """
  Generated Typesafe Sdk client facade over `TypeSafeSDK.Client`.
  """

  @spec new(keyword()) :: TypeSafeSDK.Client.t()
  def new(opts \\ []) when is_list(opts) do
    TypeSafeSDK.Client.new(opts)
  end
end
