defmodule TypeSafeSDK.Models do
  alias TypeSafeSDK.Generated.Models, as: GeneratedModels

  @moduledoc "Models API resource."

  alias TypeSafeSDK.{Client, ListModelsResponse}

  @spec list(Client.t(), keyword()) :: {:ok, ListModelsResponse.t()} | {:error, term()}
  def list(%Client{} = client, opts \\ []) when is_list(opts) do
    case GeneratedModels.list(client, %{}, opts) do
      {:ok, body} -> ListModelsResponse.decode(body)
      {:error, error} -> {:error, error}
    end
  end
end
