Code.require_file("../../examples/support/live.exs", __DIR__)

defmodule TypeSafeSDK.LiveExampleConfigurationTest do
  use ExUnit.Case, async: false

  alias TypeSafeSDK.Examples.Live

  @env_names ["TYPESAFE_API_KEY", "TYPESAFE_BASE_URL", "TYPESAFE_DEFAULT_MODEL"]

  setup do
    previous_env = Map.new(@env_names, &{&1, System.get_env(&1)})
    previous_app = Application.get_all_env(:typesafe_sdk)

    on_exit(fn ->
      Enum.each(previous_env, fn
        {name, nil} -> System.delete_env(name)
        {name, value} -> System.put_env(name, value)
      end)

      for {key, _value} <- Application.get_all_env(:typesafe_sdk),
          do: Application.delete_env(:typesafe_sdk, key)

      for {key, value} <- previous_app, do: Application.put_env(:typesafe_sdk, key, value)
    end)

    Enum.each(@env_names, &System.delete_env/1)
    :ok
  end

  test "environment endpoint/model are selected and live transport/retry defaults stay fixed" do
    System.put_env("TYPESAFE_API_KEY", "env-key")
    System.put_env("TYPESAFE_BASE_URL", "https://provider.example/deployments/type-safe/")
    System.put_env("TYPESAFE_DEFAULT_MODEL", "provider-model")

    client = Live.client()

    assert client.api_key == "env-key"
    assert client.base_url == "https://provider.example/deployments/type-safe"
    assert client.default_model == "provider-model"
    assert client.retry == false
    assert client.transport == Pristine.Adapters.Transport.Finch
    assert client.transport_opts == []
  end

  test "explicit timeout units win over the live helper default" do
    System.put_env("TYPESAFE_API_KEY", "env-key")

    assert Live.client(timeout: 7).timeout_ms == 7_000
    assert Live.client(timeout_ms: 8_500).timeout_ms == 8_500
  end

  test "explicit live options win over environment defaults" do
    System.put_env("TYPESAFE_API_KEY", "env-key")
    System.put_env("TYPESAFE_BASE_URL", "https://env.example/root")
    System.put_env("TYPESAFE_DEFAULT_MODEL", "env-model")

    client =
      Live.client(
        api_key: "explicit-key",
        base_url: "https://explicit.example/prefix/",
        model: "explicit-model",
        retry: [max_retries: 1]
      )

    assert client.api_key == "explicit-key"
    assert client.base_url == "https://explicit.example/prefix"
    assert client.default_model == "explicit-model"
    assert client.retry.max_retries == 1
  end

  test "explicit executable options outrank even unusable lower-precedence environment values" do
    System.put_env("TYPESAFE_API_KEY", "env-key")
    System.put_env("TYPESAFE_BASE_URL", "   ")
    System.put_env("TYPESAFE_DEFAULT_MODEL", "   ")

    client =
      Live.client(
        base_url: "https://explicit.example/root",
        model: "explicit-model"
      )

    assert client.base_url == "https://explicit.example/root"
    assert client.default_model == "explicit-model"
  end

  test "application config is used when no live environment override is selected" do
    Application.put_env(:typesafe_sdk, :api_key, "configured-key")
    Application.put_env(:typesafe_sdk, :base_url, "https://configured.example/root")
    Application.put_env(:typesafe_sdk, :default_model, "configured-model")

    client = Live.client()

    assert client.api_key == "configured-key"
    assert client.base_url == "https://configured.example/root"
    assert client.default_model == "configured-model"
  end

  test "blank live endpoint/model environment values fail instead of falling back" do
    System.put_env("TYPESAFE_API_KEY", "env-key")

    System.put_env("TYPESAFE_BASE_URL", "   ")
    assert_raise ArgumentError, ~r/TYPESAFE_BASE_URL is set but blank/, fn -> Live.client() end

    System.delete_env("TYPESAFE_BASE_URL")
    System.put_env("TYPESAFE_DEFAULT_MODEL", "   ")
    assert_raise ArgumentError, ~r/TYPESAFE_DEFAULT_MODEL is set but blank/, fn -> Live.client() end
  end

  test "caller cannot swap a fixture transport into a live example client" do
    System.put_env("TYPESAFE_API_KEY", "env-key")

    client =
      Live.client(
        transport: TypeSafeSDK.Test.Transport,
        transport_opts: [scenario: self()]
      )

    assert client.transport == Pristine.Adapters.Transport.Finch
    assert client.transport_opts == []
  end
end
