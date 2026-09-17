defmodule TypeSafeSDK.Generated.SystemOne do
  @moduledoc """
  Generated Typesafe Sdk operations module `TypeSafeSDK.Generated.SystemOne`.
  """

  alias Pristine.SDK.OpenAPI.Client, as: OpenAPIClient

  @create_partition_spec %{
    path: [],
    body: %{mode: :remaining},
    query: [],
    headers: [],
    form_data: %{mode: :none}
  }

  @doc "Answer one or more questions about the content supplied in `state`.\n\nYou can mix question types in one request. Answers use the same names as the\nquestions, so you can match each result to its question. The response also includes\nthe model used and token usage."
  @spec create(term(), map(), keyword()) :: {:ok, term()} | {:error, term()}
  def create(client, params \\ %{}, opts \\ [])
      when is_map(params) and is_list(opts) do
    opts = normalize_request_opts!(opts)
    request = build_create_request(client, params, opts)
    TypeSafeSDK.Client.execute_generated_request(client, request)
  end

  defp build_create_request(client, params, opts)
       when is_map(params) and is_list(opts) do
    _ = client
    partition = OpenAPIClient.partition(params, @create_partition_spec)

    %{
      id: "system_one",
      args: params,
      call: {__MODULE__, :create},
      opts: opts,
      method: :post,
      path_template: "/v1/systemone",
      path_params: partition.path_params,
      query: partition.query,
      headers: partition.headers,
      body: partition.body,
      form_data: partition.form_data,
      request_schema: TypeSafeSDK.Generated.Schemas.SystemOneRequest,
      response_schemas: %{200 => TypeSafeSDK.Generated.Schemas.SystemOneResponse},
      auth: %{use_client_default?: true, override: nil, security_schemes: ["BearerAuth"]},
      resource: "system_one",
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
