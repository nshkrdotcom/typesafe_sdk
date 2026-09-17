defmodule TypeSafeSDK.Schema do
  @moduledoc """
  Self-contained JSON Schemas derived from the committed OpenAPI 3.1 document.

  These are the wire schemas, not a second definition of stricter semantic
  constraints (option count, relational domains, probability sums). All component
  references become local `$defs` references. Unknown OpenAPI annotations survive.
  """
  @roots %{"system-one-request.json" => "SystemOneRequest",
           "system-one-response.json" => "SystemOneResponse",
           "models-response.json" => "ModelMetadataList"}

  @spec source_path() :: String.t()
  def source_path, do: Application.app_dir(:typesafe_sdk, "priv/upstream/openapi.json")

  @spec documents(map()) :: %{String.t() => map()}
  def documents(openapi) do
    unless String.starts_with?(Map.get(openapi, "openapi", ""), "3.1."),
      do: raise(ArgumentError, "schema export requires the committed OpenAPI 3.1 contract")
    components = openapi |> Map.fetch!("components") |> Map.fetch!("schemas")
    definitions = rewrite(components)
    validate_references!(definitions, %{"$defs" => definitions})
    Map.new(@roots, fn {filename, root} ->
      Map.fetch!(components, root)
      {filename, %{"$schema" => "https://json-schema.org/draft/2020-12/schema",
        "$ref" => "#/$defs/#{root}", "$defs" => definitions,
        "title" => root, "x-typesafe-sdk-version" => TypeSafeSDK.version(),
        "x-source" => "priv/upstream/openapi.json"}}
    end)
  end

  @spec export(String.t(), String.t()) :: :ok
  def export(directory, source \\ source_path()) do
    File.mkdir_p!(directory)
    source |> File.read!() |> Jason.decode!() |> documents()
    |> Enum.each(fn {filename, document} ->
      path = Path.join(directory, filename)
      temporary = path <> ".tmp-" <> Integer.to_string(System.unique_integer([:positive]))
      try do
        content = document |> TypeSafeSDK.JSON.ordered() |> Jason.encode!(pretty: true)
        File.write!(temporary, content <> "\n")
        File.rename!(temporary, path)
      after
        File.rm(temporary)
      end
    end)
    :ok
  end

  @spec verify(String.t(), String.t()) :: :ok | {:error, [String.t()]}
  def verify(directory, source \\ source_path()) do
    expected = source |> File.read!() |> Jason.decode!() |> documents()
    stale = Enum.flat_map(expected, fn {filename, document} ->
      with {:ok, bytes} <- File.read(Path.join(directory, filename)),
           {:ok, actual} <- Jason.decode(bytes),
           true <- actual == document do
        []
      else
        _ -> [filename]
      end
    end)
    extra = directory |> Path.join("*.json") |> Path.wildcard() |> Enum.map(&Path.basename/1)
      |> Enum.reject(&Map.has_key?(expected, &1))
    case Enum.sort(stale ++ extra) do
      [] -> :ok
      mismatches -> {:error, mismatches}
    end
  end

  # Rewrite reference values, not descriptions or example strings that happen
  # to look like references. Unsupported references fail rather than producing
  # a schema falsely advertised as self-contained.
  defp rewrite(value) when is_map(value) do
    Map.new(value, fn
      {key, "#/components/schemas/" <> reference} when key in ["$ref", "$dynamicRef"] ->
        {key, "#/$defs/" <> reference}
      {"discriminator", %{"mapping" => mapping} = discriminator} ->
        mapping = Map.new(mapping, fn
          {tag, "#/components/schemas/" <> reference} -> {tag, "#/$defs/" <> reference}
          pair -> pair
        end)
        {"discriminator", rewrite(Map.put(discriminator, "mapping", mapping))}
      {key, item} -> {key, rewrite(item)}
    end)
  end
  defp rewrite(value) when is_list(value), do: Enum.map(value, &rewrite/1)
  defp rewrite(value), do: value

  defp validate_references!(value, root) when is_map(value) do
    Enum.each(value, fn
      {key, reference} when key in ["$ref", "$dynamicRef"] -> resolve_reference!(reference, root)
      {"discriminator", %{"mapping" => mapping} = discriminator} ->
        Enum.each(mapping, fn {_, reference} -> resolve_reference!(reference, root) end)
        validate_references!(Map.delete(discriminator, "mapping"), root)
      {_, item} -> validate_references!(item, root)
    end)
  end
  defp validate_references!(value, root) when is_list(value),
    do: Enum.each(value, &validate_references!(&1, root))
  defp validate_references!(_, _), do: :ok

  defp resolve_reference!("#/$defs/" <> tail, root) do
    tokens = ["$defs" | String.split(tail, "/")]
    Enum.reduce(tokens, root, fn token, value ->
      token = token |> String.replace("~1", "/") |> String.replace("~0", "~")
      case value do
        value when is_map(value) -> Map.fetch!(value, token)
        value when is_list(value) ->
          case Integer.parse(token) do
            {index, ""} when index >= 0 -> Enum.fetch!(value, index)
            _ -> raise ArgumentError, "invalid JSON pointer in schema reference"
          end
        _ -> raise ArgumentError, "unresolved JSON pointer in schema reference"
      end
    end)
    :ok
  end
  defp resolve_reference!(_, _),
    do: raise(ArgumentError, "schema export cannot resolve external or non-component references")
end
