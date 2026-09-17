defmodule TypeSafeSDK.Examples.Live do
  @moduledoc false

  def client do
    key = System.get_env("TYPESAFE_API_KEY")

    if is_nil(key) or String.trim(key) == "" do
      raise ArgumentError, "Set TYPESAFE_API_KEY before running a live example"
    end

    # Explicit live endpoint and transport: host test/config overrides cannot
    # silently turn a live example into a fixture run. Disable automatic replay.
    TypeSafeSDK.new_client(
      api_key: key,
      base_url: "https://api.typesafe.ai",
      model: System.get_env("TYPESAFE_DEFAULT_MODEL") || "jev-latest",
      transport: Pristine.Adapters.Transport.Finch,
      transport_opts: [],
      retry: false,
      timeout_ms: 15_000
    )
  end

  def unwrap!({:ok, value}), do: value

  def unwrap!({:error, %TypeSafeSDK.Error{} = error}) do
    show("Request failure", %{
      type: error.type,
      status: error.status,
      path: error.path,
      request_id: error.request_id,
      retryable_under_default_policy: TypeSafeSDK.Error.retryable?(error),
      retry_after_ms: TypeSafeSDK.Error.retry_after(error)
    })

    raise error
  end

  def show(label, value) do
    IO.puts("\n#{label}")
    IO.inspect(value, pretty: true, limit: :infinity, width: 100)
  end

  def summary(response) do
    %{
      model: response.model,
      request_id: response.request_id,
      retries: response.retries,
      elapsed_ms: response.elapsed_ms,
      runtime_elapsed_ms: response.runtime_elapsed_ms,
      batch_index: response.batch_index,
      usage: response.usage
    }
  end
end
