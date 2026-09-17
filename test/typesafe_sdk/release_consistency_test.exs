defmodule TypeSafeSDK.ReleaseConsistencyTest do
  use ExUnit.Case, async: true

  test "SDK, Mix, source-ref, changelog and schema metadata share the release version" do
    assert TypeSafeSDK.version() == "0.4.0"
    assert Mix.Project.config()[:version] == "0.4.0"
    assert Mix.Project.config()[:docs][:source_ref] == "v0.4.0"
    changelog = File.read!("CHANGELOG.md")
    assert changelog =~ "## [0.4.0] - 2026-09-17"
    assert File.read!("README.md") =~ ~s({:typesafe_sdk, "~> 0.4.0"})

    for path <- Path.wildcard("priv/json_schema/*.json") do
      assert Jason.decode!(File.read!(path))["x-typesafe-sdk-version"] == "0.4.0"
    end
  end

  test "HTTP identification uses the same release version" do
    client = TypeSafeSDK.Test.client() |> TypeSafeSDK.Test.stub(q: {:noul, 1})
    assert {:ok, _} = TypeSafeSDK.evaluate(client, "synthetic", q: TypeSafeSDK.noul("Q?"))
    [request] = TypeSafeSDK.Test.requests(client)
    headers = Map.new(request.headers, fn {key, value} -> {String.downcase(key), value} end)
    assert headers["user-agent"] == "typesafe-sdk/0.4.0"
    assert headers["x-typesafe-sdk"] == "typesafe-sdk/0.4.0"
  end

  test "all registered documentation and package assets exist in the checkout" do
    docs = Mix.Project.config()[:docs]

    for entry <- docs[:extras] do
      path = if is_tuple(entry), do: elem(entry, 0), else: entry
      assert File.regular?(path), "missing documentation: #{path}"
    end

    for path <- [
          "LICENSE",
          "assets/typesafe_sdk.svg",
          "guides",
          "cheatsheets",
          "priv/json_schema",
          "examples/evaluation",
          "docs/implementation/0.4.0",
          ".reach.exs"
        ] do
      assert File.exists?(path), "missing package asset: #{path}"
    end
  end
end
