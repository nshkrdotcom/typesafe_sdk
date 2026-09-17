defmodule TypeSafeSDK.ClientConfigurationTest do
  use ExUnit.Case, async: false

  alias TypeSafeSDK.Client

  setup do
    previous = Application.get_all_env(:typesafe_sdk)

    on_exit(fn ->
      for {key, _value} <- Application.get_all_env(:typesafe_sdk) do
        Application.delete_env(:typesafe_sdk, key)
      end

      for {key, value} <- previous, do: Application.put_env(:typesafe_sdk, key, value)
    end)

    :ok
  end

  test "explicit configuration wins and trailing slashes are removed" do
    client =
      Client.new(
        api_key: " key ",
        base_url: "https://example.test///",
        model: "jev-x",
        timeout: 2.5
      )

    assert client.api_key == "key"
    assert client.base_url == "https://example.test"
    assert client.default_model == "jev-x"
    assert client.timeout_ms == 2_500
  end

  test "application configuration is the runtime environment boundary" do
    Application.put_env(:typesafe_sdk, :api_key, "configured")
    Application.put_env(:typesafe_sdk, :base_url, "https://configured.test/")
    Application.put_env(:typesafe_sdk, :default_model, "configured-model")

    client = Client.new()
    assert client.api_key == "configured"
    assert client.base_url == "https://configured.test"
    assert client.default_model == "configured-model"
  end

  test "explicit nil inherits application configuration like Python None" do
    Application.put_env(:typesafe_sdk, :api_key, "configured")
    Application.put_env(:typesafe_sdk, :base_url, "https://configured.test/")
    Application.put_env(:typesafe_sdk, :default_model, "configured-model")

    client = Client.new(api_key: nil, base_url: nil, model: nil, timeout: nil, retry: nil)
    assert client.api_key == "configured"
    assert client.base_url == "https://configured.test"
    assert client.default_model == "configured-model"
    assert client.timeout_ms == 10_000
    assert %TypeSafeSDK.RetryPolicy{} = client.retry
  end

  test "missing key raises a TypeSafeSDK.Error" do
    Application.delete_env(:typesafe_sdk, :api_key)
    assert_raise TypeSafeSDK.Error, ~r/No API key/, fn -> Client.new() end
  end
end
