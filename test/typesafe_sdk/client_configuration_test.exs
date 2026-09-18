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

  test "path-prefixed base URLs are retained and normalized" do
    client =
      Client.new(
        api_key: "key",
        base_url: " https://example.test/accounts/acme/typesafe/// ",
        model: "provider-model"
      )

    assert client.base_url == "https://example.test/accounts/acme/typesafe"
    assert client.default_model == "provider-model"
  end

  test "explicit invalid endpoint settings fail instead of falling back" do
    for {base_url, message} <- [
          {"   ", ~r/base_url must not be blank/},
          {"example.test/typesafe", ~r/base_url must use http or https/},
          {"ftp://example.test/typesafe", ~r/base_url must use http or https/},
          {"https:///typesafe", ~r/base_url must include a host/},
          {"https://user:secret@example.test/typesafe", ~r/URL credentials/},
          {"https://example.test/typesafe?token=secret", ~r/query string/},
          {"https://example.test/typesafe#fragment", ~r/fragment/}
        ] do
      assert_raise TypeSafeSDK.Error, message, fn ->
        Client.new(api_key: "key", base_url: base_url, model: "provider-model")
      end
    end
  end

  test "explicit blank model fails instead of selecting a different provider model" do
    assert_raise TypeSafeSDK.Error, ~r/model must not be blank/, fn ->
      Client.new(api_key: "key", base_url: "https://example.test", model: "   ")
    end
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
