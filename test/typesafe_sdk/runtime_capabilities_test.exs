defmodule TypeSafeSDK.RuntimeCapabilitiesTest do
  use ExUnit.Case, async: true
  alias TypeSafeSDK.{Error, RuntimeCapabilities, Test}

  defmodule Advertisement do
    def typesafe_capabilities(opts), do: Map.new(opts)
  end
  defmodule BrokenAdvertisement do
    def typesafe_capabilities(_), do: raise("not available")
  end

  test "unknown transport capabilities are unverified and requirements fail closed" do
    client = Test.client()
    report = RuntimeCapabilities.report(client)
    assert Enum.all?(report.runtime, fn {_, value} -> value == :unverified end)
    assert :ok = RuntimeCapabilities.check(client, [])
    assert {:error, %Error{type: :runtime_capability, details: %{missing: [:max_response_bytes]}}} =
      RuntimeCapabilities.check(client, [:max_response_bytes])
    assert_raise Error, fn -> Test.client(runtime_requirements: [:bounded_queue]) end
  end

  test "numeric bounds and guarantees are labeled advertised, never independently verified" do
    client = %{transport: Advertisement, transport_opts: [bounded_queue: 0,
      max_response_bytes: 1024, cancellation_cleanup: true, bounded_outstanding_requests: 8]}
    report = RuntimeCapabilities.report(client)
    assert report.runtime.bounded_queue == %{status: :advertised, value: 0}
    assert report.runtime.max_response_bytes.value == 1024
    assert :ok = RuntimeCapabilities.check(client, [:bounded_queue, :cancellation_cleanup])
    assert report.runtime.deterministic_overload == :unverified
  end

  test "malformed or broken advertisements are not accepted as guarantees" do
    report = RuntimeCapabilities.report(%{transport: Advertisement, transport_opts: [max_response_bytes: true, bounded_queue: -1]})
    assert report.runtime.max_response_bytes == :unverified
    assert report.runtime.bounded_queue == :unverified
    assert RuntimeCapabilities.report(%{transport: BrokenAdvertisement, transport_opts: []}).runtime.max_response_bytes == :unverified
  end
end
