defmodule TypeSafeSDK.SchemaTest do
  use ExUnit.Case, async: true
  alias TypeSafeSDK.Schema

  setup do
    directory =
      Path.join(System.tmp_dir!(), "typesafe-schema-#{System.unique_integer([:positive])}")

    on_exit(fn -> File.rm_rf(directory) end)
    %{directory: directory}
  end

  test "all committed self-contained schemas match their authoritative source" do
    assert :ok = Schema.verify("priv/json_schema")
    docs = Schema.source_path() |> File.read!() |> Jason.decode!() |> Schema.documents()
    assert map_size(docs) == 3

    for {_, document} <- docs do
      refute Jason.encode!(document) =~ "#/components/schemas/"
      assert document["x-typesafe-sdk-version"] == "0.4.0"

      for reference <- references(document) do
        assert String.starts_with?(reference, "#/$defs/")
        assert Map.has_key?(document["$defs"], String.replace_prefix(reference, "#/$defs/", ""))
      end
    end
  end

  test "export is deterministic and verification detects missing, malformed and stale documents", %{
    directory: directory
  } do
    assert {:error, files} = Schema.verify(directory)
    assert length(files) == 3
    assert :ok = Schema.export(directory)
    before = Map.new(Path.wildcard(Path.join(directory, "*.json")), &{&1, File.read!(&1)})
    assert :ok = Schema.export(directory)
    assert Enum.all?(before, fn {file, bytes} -> File.read!(file) == bytes end)
    assert :ok = Schema.verify(directory)
    path = Path.join(directory, "system-one-request.json")
    File.write!(path, "not json")
    assert {:error, ["system-one-request.json"]} = Schema.verify(directory)
    Schema.export(directory)
    File.write!(Path.join(directory, "obsolete.json"), "{}")
    assert {:error, ["obsolete.json"]} = Schema.verify(directory)
  end

  defp references(map) when is_map(map),
    do:
      Enum.flat_map(map, fn
        {"$ref", reference} -> [reference]
        {_, value} -> references(value)
      end)

  defp references(list) when is_list(list), do: Enum.flat_map(list, &references/1)
  defp references(_), do: []

  test "annotations survive unchanged and unsupported external references fail closed" do
    source = Schema.source_path() |> File.read!() |> Jason.decode!()

    annotated =
      put_in(
        source,
        ["components", "schemas", "SystemOneRequest", "description"],
        "#/components/schemas/SystemOneRequest"
      )

    docs = Schema.documents(annotated)

    assert docs["system-one-request.json"]["$defs"]["SystemOneRequest"]["description"] ==
             "#/components/schemas/SystemOneRequest"

    external =
      put_in(
        source,
        ["components", "schemas", "SystemOneRequest", "$ref"],
        "https://example.invalid/schema.json"
      )

    assert_raise ArgumentError, fn -> Schema.documents(external) end

    missing =
      put_in(
        source,
        ["components", "schemas", "SystemOneRequest", "$ref"],
        "#/components/schemas/NotPresent"
      )

    assert_raise KeyError, fn -> Schema.documents(missing) end
  end
end
