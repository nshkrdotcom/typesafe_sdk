defmodule TypeSafeSDK.Generated.Models do
  @moduledoc """
  Generated Typesafe Sdk operations module `TypeSafeSDK.Generated.Models`.
  """

  alias Pristine.SDK.OpenAPI.Client, as: OpenAPIClient

  @list_partition_spec %{
    path: [],
    body: %{mode: :none},
    query: [],
    headers: [],
    form_data: %{mode: :none}
  }

  @doc "List the models and aliases available to the authenticated account.\n\nPass a returned model name as `model` in a POST /v1/systemone request."
  @spec list(term(), map(), keyword()) :: {:ok, term()} | {:error, term()}
  def list(client, params \\ %{}, opts \\ [])
      when is_map(params) and is_list(opts) do
    opts = normalize_request_opts!(opts)
    request = build_list_request(client, params, opts)
    TypeSafeSDK.Client.execute_generated_request(client, request)
  end

  defp build_list_request(client, params, opts)
       when is_map(params) and is_list(opts) do
    _ = client
    partition = OpenAPIClient.partition(params, @list_partition_spec)

    %{
      id: "list_models",
      args: params,
      call: {__MODULE__, :list},
      opts: opts,
      method: :get,
      path_template: "/v1/models",
      path_params: partition.path_params,
      query: partition.query,
      headers: partition.headers,
      body: partition.body,
      form_data: partition.form_data,
      request_schema: nil,
      response_schemas: %{200 => TypeSafeSDK.Generated.Schemas.ModelMetadataList},
      auth: %{use_client_default?: true, override: nil, security_schemes: ["BearerAuth"]},
      resource: "models",
      retry: "typesafe.default",
      circuit_breaker: nil,
      rate_limit: nil,
      telemetry: nil,
      timeout: nil,
      pagination: nil
    }
  end

  @spec normalize_request_opts!(list()) :: keyword()
  defp normalize_request_opts!(opts) when is_list(opts) do
    if Keyword.keyword?(opts) do
      opts
    else
      raise ArgumentError, "request opts must be a keyword list"
    end
  end
end
