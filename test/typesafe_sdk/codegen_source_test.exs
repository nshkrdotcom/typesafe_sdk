defmodule TypeSafeSDK.CodegenSourceTest do
  use ExUnit.Case, async: true

  alias TypeSafeSDK.Codegen.Source.OpenAPI

  test "committed OpenAPI snapshot covers the bounded SDK surface" do
    dataset = OpenAPI.load(TypeSafeSDK.Codegen.Provider, project_root: File.cwd!())
    assert Enum.map(dataset.operations, & &1.id) |> Enum.sort() == ["list_models", "system_one"]
    assert length(dataset.schemas) == 12
    assert [%{id: "bearer"}] = dataset.auth_policies

    snapshot = File.read!("priv/upstream/openapi.json") |> Jason.decode!()

    assert get_in(snapshot, ["components", "schemas", "Usage", "required"]) == [
             "input_tokens",
             "output_tokens"
           ]
  end
end
