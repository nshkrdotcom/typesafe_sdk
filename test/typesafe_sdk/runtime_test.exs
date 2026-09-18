defmodule TypeSafeSDK.RuntimeTest do
  use ExUnit.Case, async: true

  alias ExecutionPlane.Contracts.Failure
  alias Pristine.Core.Response
  alias TypeSafeSDK.{Client, Error, RetryPolicy}

  defmodule Transport do
    @behaviour Pristine.Ports.Transport

    @impl true
    def send(request, context) do
      Agent.get_and_update(context.transport_opts[:scenario], fn {[result | rest], requests} ->
        {result, {rest, requests ++ [request]}}
      end)
    end
  end

  defp client(results, opts \\ []) do
    {:ok, scenario} = Agent.start_link(fn -> {results, []} end)

    opts =
      Keyword.merge(
        [
          api_key: "test-key",
          transport: Transport,
          transport_opts: [scenario: scenario],
          retry: [backoff_initial: 0]
        ],
        opts
      )

    {Client.new(opts), scenario}
  end

  defp response(status, body \\ %{"models" => []}, headers \\ %{}) do
    {:ok,
     %Response{
       status: status,
       body: Jason.encode!(body),
       headers: Map.put(headers, "content-type", "application/json")
     }}
  end

  defp requests(scenario), do: Agent.get(scenario, &elem(&1, 1))
  defp headers(request), do: Map.new(request.headers, fn {k, v} -> {String.downcase(k), v} end)

  test "generated System One preserves extra body, protected headers, timeout and metadata" do
    payload = %{
      "model" => "jev-latest",
      "usage" => %{"input_tokens" => 1, "output_tokens" => 2},
      "answers" => %{"ok" => %{"type" => "noul", "noul" => 0.9}}
    }

    forged =
      Map.new(
        ~w(authorization accept content-type user-agent x-typesafe-sdk x-typesafe-runtime x-typesafe-retry-count),
        &{&1, "forged"}
      )

    {client, scenario} =
      client([response(200, payload, %{"x-typesafe-request-id" => "req-1"})],
        headers: forged,
        timeout: 8
      )

    assert {:ok, result} =
             TypeSafeSDK.system_one(
               client,
               "original",
               %{ok: %{"type" => "noul", "instructions" => "yes?", "future" => true}},
               timeout: 1.25,
               extra_headers: Map.put(forged, "x-custom", "kept"),
               extra_body: %{state: "replacement", model: "custom", future_top: true}
             )

    assert result.request_id == "req-1"
    assert result.answers["ok"].noul == 0.9
    [request] = requests(scenario)
    assert request.metadata.timeout == 1_250
    assert request.method == :post
    assert String.ends_with?(request.url, "/v1/systemone")

    assert %{
             "state" => "replacement",
             "model" => "custom",
             "future_top" => true,
             "questions" => %{"ok" => %{"future" => true}}
           } = Jason.decode!(request.body)

    actual = headers(request)
    assert actual["authorization"] == "Bearer test-key"
    assert actual["accept"] == "application/json"
    assert actual["content-type"] == "application/json"
    assert actual["x-custom"] == "kept"
    refute Map.has_key?(actual, "x-typesafe-retry-count")

    for key <- ~w(user-agent x-typesafe-sdk x-typesafe-runtime),
        do: refute(actual[key] in [nil, "forged"])
  end

  test "path-prefixed base URL reaches generated operations without weakening auth headers" do
    forged = %{"authorization" => "Bearer forged", "x-typesafe-sdk" => "forged"}

    {client, scenario} =
      client([response(200)],
        base_url: "https://example.test/accounts/acme/typesafe/",
        headers: forged,
        retry: false
      )

    assert {:ok, _} = TypeSafeSDK.list_models(client)
    [request] = requests(scenario)

    assert request.url == "https://example.test/accounts/acme/typesafe/v1/models"

    actual = headers(request)
    assert actual["authorization"] == "Bearer test-key"
    refute actual["x-typesafe-sdk"] == "forged"
  end

  test "default retries all 5xx and sends attempt headers only on retries" do
    {client, scenario} = client([response(529), response(599), response(200)])
    assert {:ok, _} = TypeSafeSDK.list_models(client)
    assert Enum.map(requests(scenario), &headers(&1)["x-typesafe-retry-count"]) == [nil, "1", "2"]
  end

  test "per-call policy replaces client status set and can disable retries" do
    for {status, options, expected_attempts} <- [
          {409, [retry: [http_statuses: [409], backoff_initial: 0]], 2},
          {500, [retry: [http_statuses: [409], backoff_initial: 0]], 1},
          {429, [retry: false], 1}
        ] do
      {client, scenario} = client([response(status), response(200)])
      result = TypeSafeSDK.list_models(client, options)

      if expected_attempts == 2,
        do: assert(match?({:ok, _}, result)),
        else: assert(match?({:error, %Error{}}, result))

      assert length(requests(scenario)) == expected_attempts
    end
  end

  test "Retry-After controls delay unless explicitly disabled" do
    for {header, value, delay, respect} <- [
          {"Retry-After", "2", 2_000, true},
          {"retry-after-ms", "12", 12, true},
          {"Retry-After", "2", 0, false}
        ] do
      {client, _} =
        client([response(429, %{}, %{header => value}), response(200)],
          retry: [backoff_initial: 0, respect_retry_after: respect]
        )

      parent = self()

      context = %{
        client.context
        | retry_opts:
            Keyword.put(client.context.retry_opts, :sleep_fun, fn ms ->
              send(parent, {:delay, ms})
            end)
      }

      assert {:ok, _} = TypeSafeSDK.list_models(%{client | context: context})
      assert_receive {:delay, ^delay}
    end
  end

  test "lower transport timeout and connection flags are independent" do
    for {reason, policy, attempts} <- [
          {:timeout, [api_timeout_error: false, api_connection_error: true], 1},
          {:econnrefused, [api_timeout_error: false, api_connection_error: true], 2},
          {:timeout, [api_timeout_error: true, api_connection_error: false], 2},
          {:econnrefused, [api_timeout_error: true, api_connection_error: false], 1}
        ] do
      failure = Failure.new!(%{failure_class: :transport_failed, reason: "http request failed"})

      {client, scenario} =
        client(
          [
            {:error, {:execution_plane_transport, failure, %{error: inspect(reason)}}},
            response(200)
          ],
          retry: Keyword.put(policy, :backoff_initial, 0)
        )

      result = TypeSafeSDK.list_models(client)

      if attempts == 1 do
        expected_type = if reason == :timeout, do: :timeout, else: :connection
        assert {:error, %Error{type: ^expected_type}} = result
      end

      assert length(requests(scenario)) == attempts
    end
  end

  test "retry budget preserves last HTTP error without sleeping past budget" do
    {client, scenario} =
      client([response(529, %{"message" => "busy"}, %{"retry-after" => "1"})],
        retry: [timeout: 0.001]
      )

    assert {:error, %Error{status: 529, type: :internal_server}} = TypeSafeSDK.list_models(client)
    assert length(requests(scenario)) == 1
    assert RetryPolicy.to_pristine_opts(%RetryPolicy{})[:retry_budget_ms] == 30_000
  end
end
