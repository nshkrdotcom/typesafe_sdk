defmodule TypeSafeSDK do
  @moduledoc """
  Elixir client for the TypeSafe AI API.

  This port keeps the Python SDK's two public API operations while using the
  Pristine runtime and generated-provider conventions used by sibling Elixir SDKs.
  """

  alias TypeSafeSDK.{Client, Models, SystemOne}

  @version "0.1.0"

  @spec version() :: String.t()
  def version, do: @version

  @spec new_client(keyword()) :: Client.t()
  defdelegate new_client(opts \\ []), to: Client, as: :new

  @spec system_one(Client.t(), term(), map(), keyword()) ::
          {:ok, TypeSafeSDK.SystemOneResponse.t()} | {:error, term()}
  defdelegate system_one(client, state, questions, opts \\ []), to: SystemOne, as: :run

  @spec list_models(Client.t(), keyword()) ::
          {:ok, TypeSafeSDK.ListModelsResponse.t()} | {:error, term()}
  defdelegate list_models(client, opts \\ []), to: Models, as: :list
end
