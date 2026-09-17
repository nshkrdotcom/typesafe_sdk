defmodule TypeSafeSDK.RuntimeCapabilitiesTest do
  use ExUnit.Case, async: true

  alias TypeSafeSDK.{Client, Error, RuntimeCapabilities, Test}

  defmodule Advertisement do
    @behaviour Pristine.Ports.Transport

    @impl true
    def capabilities(context), do: Map.new(context.transport_opts)

    @impl true
    def send(_request, _context), do: {:error, :not_used}
  end

  defmodule BrokenAdvertisement do
    @behaviour Pristine.Ports.Transport

    @impl true
    def capabilities(_context), do: raise("not available")

    @impl true
    def send(_request, _context), do: {:error, :not_used}
  end

  test "discovery delegates to Pristine and fails closed for unadvertised capabilities" do
    client = Test.client()
    report = RuntimeCapabilities.report(client)

    assert report.runtime.unary_cancellation == %{status: :supported}
    assert report.runtime.cancellation_cleanup == %{status: :supported}
    assert report.runtime.max_response_bytes == %{status: :unverified}
    assert :ok = RuntimeCapabilities.check(client, [:unary_cancellation, :cancellation_cleanup])

    assert {:error, %Error{type: :runtime_capability, details: %{missing: [:max_response_bytes]}}} =
             RuntimeCapabilities.check(client, [:max_response_bytes])
  end

  test "custom Pristine capability advertisements retain normalized bounded values" do
    client =
      Client.new(
        api_key: "test",
        transport: Advertisement,
        transport_opts: [bounded_queue: 0, max_response_bytes: 1024]
      )

    report = RuntimeCapabilities.report(client)
    assert report.runtime.bounded_queue == %{status: :supported, value: 0}
    assert report.runtime.max_response_bytes == %{status: :supported, value: 1024}
    assert :ok = RuntimeCapabilities.check(client, [:bounded_queue, :max_response_bytes])
    assert report.runtime.unary_cancellation == %{status: :unverified}
  end

  test "malformed or broken advertisements are unverified and cannot satisfy requirements" do
    client = Client.new(api_key: "test", transport: BrokenAdvertisement)
    report = RuntimeCapabilities.report(client)
    assert report.runtime.unary_cancellation == %{status: :unverified}

    assert_raise Error, fn ->
      Client.new(
        api_key: "test",
        transport: BrokenAdvertisement,
        runtime_requirements: [:unary_cancellation]
      )
    end
  end
end
