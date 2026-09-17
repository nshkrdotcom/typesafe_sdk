defmodule TypeSafeSDK.Codegen.Source.OpenAPI do
  alias TypeSafeSDK.Codegen.Provider, as: Provider

  @moduledoc false
  @behaviour PristineCodegen.Plugin.Source

  alias PristineCodegen.Source.Dataset

  @upstream_url "https://api.typesafe.ai/openapi.json"
  @schema_modules %{
    "ChoiceAnswer" => TypeSafeSDK.Generated.Schemas.ChoiceAnswer,
    "ChoiceQuestion" => TypeSafeSDK.Generated.Schemas.ChoiceQuestion,
    "ModelMetadata" => TypeSafeSDK.Generated.Schemas.ModelMetadata,
    "ModelMetadataList" => TypeSafeSDK.Generated.Schemas.ModelMetadataList,
    "NoulAnswer" => TypeSafeSDK.Generated.Schemas.NoulAnswer,
    "NoulCriteria" => TypeSafeSDK.Generated.Schemas.NoulCriteria,
    "NoulQuestion" => TypeSafeSDK.Generated.Schemas.NoulQuestion,
    "ScoreAnswer" => TypeSafeSDK.Generated.Schemas.ScoreAnswer,
    "ScoreQuestion" => TypeSafeSDK.Generated.Schemas.ScoreQuestion,
    "SystemOneRequest" => TypeSafeSDK.Generated.Schemas.SystemOneRequest,
    "SystemOneResponse" => TypeSafeSDK.Generated.Schemas.SystemOneResponse,
    "Usage" => TypeSafeSDK.Generated.Schemas.Usage
  }
  @operation_specs [
    %{
      id: "system_one",
      path: "/v1/systemone",
      method: :post,
      module: TypeSafeSDK.Generated.SystemOne,
      function: :create,
      resource: "system_one"
    },
    %{
      id: "list_models",
      path: "/v1/models",
      method: :get,
      module: TypeSafeSDK.Generated.Models,
      function: :list,
      resource: "models"
    }
  ]

  @impl true
  def load(_provider_module, opts) do
    path = openapi_path(opts)
    document = path |> File.read!() |> Jason.decode!()
    ensure_openapi!(document)
    validate_union_aliases!(document)

    %Dataset{
      operations: Enum.map(@operation_specs, &operation!(document, &1)),
      schemas: schemas!(document),
      auth_policies: [bearer_policy()],
      pagination_policies: [],
      docs_inventory: docs_inventory(document),
      fingerprints: %{sources: [fingerprint(path)]}
    }
  end

  @spec refresh!(keyword()) :: :ok
  def refresh!(opts) do
    destination = openapi_path(opts)
    url = Keyword.get(opts, :openapi_url, @upstream_url)
    File.mkdir_p!(Path.dirname(destination))

    :inets.start()
    :ssl.start()

    request = {String.to_charlist(url), [{~c"accept", ~c"application/json"}]}

    ssl_options = [
      verify: :verify_peer,
      cacerts: :public_key.cacerts_get(),
      customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]
    ]

    http_options = [
      timeout: Keyword.get(opts, :refresh_timeout_ms, 30_000),
      ssl: ssl_options
    ]

    case :httpc.request(:get, request, http_options, body_format: :binary) do
      {:ok, {{_version, 200, _reason}, _headers, body}} ->
        decoded = Jason.decode!(body)
        ensure_openapi!(decoded)
        validate_bounded_surface!(decoded)
        validate_union_aliases!(decoded)
        File.write!(destination, Jason.encode_to_iodata!(decoded, pretty: true))
        :ok

      {:ok, {{_version, status, reason}, _headers, body}} ->
        raise "TypeSafe OpenAPI refresh failed: HTTP #{status} #{reason}: #{inspect(body)}"

      {:error, reason} ->
        raise "TypeSafe OpenAPI refresh failed: #{inspect(reason)}"
    end
  end

  defp operation!(document, spec) do
    operation =
      get_in(document, ["paths", spec.path, Atom.to_string(spec.method)]) ||
        raise(
          "missing OpenAPI operation " <>
            "#{spec.method |> Atom.to_string() |> String.upcase()} #{spec.path}"
        )

    request_schema = request_schema_ref(operation)
    response_schema = success_response_schema_ref(operation)

    %{
      id: spec.id,
      module: spec.module,
      function: spec.function,
      method: spec.method,
      path_template: spec.path,
      summary: operation["summary"],
      description: operation["description"],
      path_params: [],
      query_params: [],
      header_params: [],
      body: if(spec.method == :post, do: %{mode: :remaining}, else: %{mode: :none}),
      form_data: %{mode: :none},
      request_schema: request_schema,
      response_schemas: if(response_schema, do: %{200 => response_schema}, else: %{}),
      auth_policy_id: "bearer",
      pagination_policy_id: nil,
      runtime_metadata: %{resource: spec.resource, retry_group: "typesafe.default"},
      docs_metadata: %{
        doc: operation["description"] || operation["summary"] || spec.id,
        examples: []
      }
    }
  end

  defp schemas!(document) do
    components = get_in(document, ["components", "schemas"]) || %{}

    Enum.map(@schema_modules, fn {name, module} ->
      schema =
        Map.get(components, name) || raise "missing required OpenAPI component schema #{name}"

      required = MapSet.new(schema["required"] || [])
      properties = schema["properties"] || %{}

      fields =
        Enum.map(properties, fn {field_name, field_schema} ->
          %{
            name: field_name,
            type: type_spec!(field_schema),
            required: MapSet.member?(required, field_name),
            nullable: nullable?(field_schema),
            description: field_schema["description"]
          }
        end)

      %{
        id: name,
        module: module,
        type_name: :t,
        kind: :object,
        fields: fields,
        source_refs: [%{kind: "openapi_component", name: name}]
      }
    end)
  end

  defp type_spec!(%{"$ref" => ref}), do: schema_ref!(ref)

  defp type_spec!(%{"oneOf" => members}) when is_list(members),
    do: {:union, Enum.map(members, &type_spec!/1)}

  defp type_spec!(%{"anyOf" => members}) when is_list(members),
    do: {:union, Enum.map(members, &type_spec!/1)}

  defp type_spec!(%{"type" => types} = schema) when is_list(types) do
    {:union, Enum.map(types, &type_spec!(Map.put(schema, "type", &1)))}
  end

  defp type_spec!(%{"enum" => values}) when is_list(values), do: {:enum, values}
  defp type_spec!(%{"const" => value}), do: {:const, value}
  defp type_spec!(%{"type" => "string", "format" => format}), do: {:string, format}
  defp type_spec!(%{"type" => "string"}), do: :string
  defp type_spec!(%{"type" => "integer"}), do: :integer
  defp type_spec!(%{"type" => "number"}), do: :number
  defp type_spec!(%{"type" => "boolean"}), do: :boolean
  defp type_spec!(%{"type" => "null"}), do: :null
  defp type_spec!(%{"type" => "array", "items" => items}), do: {:array, type_spec!(items)}

  defp type_spec!(%{"type" => "object", "additionalProperties" => additional})
       when is_map(additional),
       do: {:map, :string, type_spec!(additional)}

  defp type_spec!(%{"type" => "object"}), do: :map
  defp type_spec!(%{}), do: :map

  defp schema_ref!("#/components/schemas/Question") do
    {:union,
     [
       {TypeSafeSDK.Generated.Schemas.NoulQuestion, :t},
       {TypeSafeSDK.Generated.Schemas.ChoiceQuestion, :t},
       {TypeSafeSDK.Generated.Schemas.ScoreQuestion, :t}
     ]}
  end

  defp schema_ref!("#/components/schemas/Answer") do
    {:union,
     [
       {TypeSafeSDK.Generated.Schemas.NoulAnswer, :t},
       {TypeSafeSDK.Generated.Schemas.ScoreAnswer, :t},
       {TypeSafeSDK.Generated.Schemas.ChoiceAnswer, :t}
     ]}
  end

  defp schema_ref!("#/components/schemas/" <> name) do
    case Map.fetch(@schema_modules, name) do
      {:ok, module} ->
        {module, :t}

      :error ->
        raise(
          "OpenAPI schema #{name} is outside the reviewed TypeSafe bounded surface; " <>
            "add an explicit schema module mapping"
        )
    end
  end

  defp schema_ref!(ref), do: raise("unsupported OpenAPI ref #{inspect(ref)}")

  defp request_schema_ref(operation) do
    operation
    |> get_in(["requestBody", "content", "application/json", "schema"])
    |> ref_name()
  end

  defp success_response_schema_ref(operation) do
    schema =
      get_in(operation, ["responses", "200", "content", "application/json", "schema"]) ||
        get_in(operation, ["responses", "201", "content", "application/json", "schema"])

    ref_name(schema)
  end

  defp ref_name(%{"$ref" => "#/components/schemas/" <> name}), do: name
  defp ref_name(_), do: nil

  defp nullable?(schema) do
    schema["nullable"] == true or
      (is_list(schema["type"]) and "null" in schema["type"]) or
      Enum.any?(schema["anyOf"] || [], &match?(%{"type" => "null"}, &1)) or
      Enum.any?(schema["oneOf"] || [], &match?(%{"type" => "null"}, &1))
  end

  defp bearer_policy do
    %{
      id: "bearer",
      mode: :use_client_default,
      security_schemes: ["BearerAuth"],
      override_source: nil,
      strategy_label: "Bearer API key"
    }
  end

  defp docs_inventory(document) do
    operations =
      Map.new(@operation_specs, fn spec ->
        operation = get_in(document, ["paths", spec.path, Atom.to_string(spec.method)]) || %{}
        {spec.id, %{summary: operation["summary"], description: operation["description"]}}
      end)

    %{guides: [], examples: [], operations: operations}
  end

  defp fingerprint(path) do
    contents = File.read!(path)

    %{
      kind: "openapi",
      path: Path.relative_to_cwd(path),
      sha256: :crypto.hash(:sha256, contents) |> Base.encode16(case: :lower)
    }
  end

  defp openapi_path(opts) do
    project_root = Keyword.get(opts, :project_root, Provider.project_root())
    Keyword.get(opts, :openapi_path, Path.join(project_root, "priv/upstream/openapi.json"))
  end

  defp ensure_openapi!(%{
         "openapi" => version,
         "paths" => paths,
         "components" => %{"schemas" => schemas}
       })
       when is_binary(version) and is_map(paths) and is_map(schemas), do: :ok

  defp ensure_openapi!(_), do: raise("invalid TypeSafe OpenAPI document")

  defp validate_union_aliases!(document) do
    for {name, members} <- [
          {"Question", ["NoulQuestion", "ChoiceQuestion", "ScoreQuestion"]},
          {"Answer", ["NoulAnswer", "ScoreAnswer", "ChoiceAnswer"]}
        ] do
      expected = Enum.map(members, &%{"$ref" => "#/components/schemas/#{&1}"})
      actual = get_in(document, ["components", "schemas", name, "oneOf"])

      if actual && Enum.sort(actual) != Enum.sort(expected) do
        raise "OpenAPI union #{name} is outside the reviewed TypeSafe bounded surface"
      end
    end
  end

  defp validate_bounded_surface!(document) do
    Enum.each(@operation_specs, fn spec ->
      _ =
        get_in(document, ["paths", spec.path, Atom.to_string(spec.method)]) ||
          raise("upstream removed required TypeSafe operation #{spec.method} #{spec.path}")
    end)

    Enum.each(Map.keys(@schema_modules), fn name ->
      _ =
        get_in(document, ["components", "schemas", name]) ||
          raise("upstream removed required TypeSafe schema #{name}")
    end)

    :ok
  end
end
