defmodule TypeSafeSDK.RuntimeControlsV030Test do
  use ExUnit.Case, async: true

  alias TypeSafeSDK.{Client, Error, RequestBudget, RetryPolicy, Test}

  defp questions, do: [q: TypeSafeSDK.noul("Q?")]

  defmodule ForwardingTransport do
    @behaviour Pristine.Ports.Transport

    @impl true
    def capabilities(_context) do
      %{unary_cancellation: :supported, cancellation_cleanup: :supported}
    end

    @impl true
    def send(_request, _context), do: {:error, :expected_cancelable_path}

    @impl true
    def send_cancelable(_request, context, token) do
      Kernel.send(Keyword.fetch!(context.transport_opts, :owner), {:forwarded_cancellation, token})

      body =
        Jason.encode!(%{
          "model" => "model-a",
          "usage" => %{},
          "answers" => %{"q" => %{"type" => "noul", "noul" => 0.9}}
        })

      {:ok,
       %Pristine.Core.Response{
         status: 200,
         headers: %{"content-type" => "application/json"},
         body: body
       }}
    end
  end

  test "retry overrides inherit omitted client fields and explicit false disables retries" do
    base = RetryPolicy.new!(max_retries: 5, backoff_initial: 0.75, backoff_max: 9.0)

    assert %RetryPolicy{max_retries: 1, backoff_initial: 0.75, backoff_max: 9.0} =
             RetryPolicy.merge!(base, max_retries: 1)

    assert false == RetryPolicy.merge!(base, false)
  end

  test "request budget uses exact serialized JSON byte boundaries including Unicode" do
    payload = %{"text" => "é"}
    exact = payload |> Jason.encode_to_iodata!() |> IO.iodata_length()

    assert :ok = RequestBudget.check(payload, exact)

    assert {:error, %Error{type: :request_too_large, details: %{actual_bytes: ^exact}}} =
             RequestBudget.check(payload, exact - 1)
  end

  test "request byte budget rejects before transport egress and counts UTF-8 serialized bytes" do
    client = Test.client(max_request_bytes: 1)

    assert {:error, %Error{type: :request_too_large} = error} =
             TypeSafeSDK.evaluate(client, "é", questions())

    assert error.details.actual_bytes > 1
    assert error.details.max_bytes == 1
    assert Test.requests(client) == []
  end

  test "per-call request budget overrides client default" do
    client = Test.client(max_request_bytes: 1) |> Test.stub(q: {:noul, 0.9})
    assert {:ok, _} = TypeSafeSDK.evaluate(client, "ok", questions(), max_request_bytes: 4096)
    assert length(Test.requests(client)) == 1
  end

  test "semantic evaluation forwards the exact cancellation token to Pristine transport" do
    token = Pristine.Cancellation.new()

    client =
      Client.new(
        api_key: "test",
        retry: false,
        transport: ForwardingTransport,
        transport_opts: [owner: self()]
      )

    assert {:ok, _response} =
             TypeSafeSDK.evaluate(client, "state", questions(), cancellation: token)

    assert_receive {:forwarded_cancellation, ^token}
  end

  test "partial per-call retry overrides inherit client max_retries at execution" do
    client =
      Test.client(retry: [max_retries: 0, backoff_initial: 0.0, backoff_max: 0.0])
      |> Test.stub_sequence([
        {:http_error, 500},
        {:answers, [q: {:noul, 0.9}]}
      ])

    assert {:error, %Error{status: 500}} =
             TypeSafeSDK.evaluate(client, "state", questions(), retry: [backoff_initial: 0.0])

    assert Test.stats(client).total == 1
  end

  test "pre-cancelled semantic evaluation stays cancellation-distinct and does not egress" do
    client = Test.client()
    token = Pristine.Cancellation.new()
    :ok = Pristine.Cancellation.cancel(token)

    assert {:error, %Error{type: :cancelled, cause: %Pristine.Error{type: :cancelled}}} =
             TypeSafeSDK.evaluate(client, "state", questions(), cancellation: token)

    assert Test.requests(client) == []
  end

  test "batch cancellation halts future scheduling" do
    owner = self()
    token = Pristine.Cancellation.new()

    client =
      Test.client()
      |> Test.stub_callback(fn request ->
        state = request.body |> IO.iodata_to_binary() |> Jason.decode!() |> Map.fetch!("state")
        send(owner, {:entered, state, self()})

        receive do
          :release -> {:answers, [q: {:noul, 0.9}]}
        end
      end)

    consumer =
      Task.async(fn ->
        TypeSafeSDK.evaluate_many(client, 0..20, questions(),
          cancellation: token,
          max_concurrency: 1,
          ordered: false
        )
      end)

    assert_receive {:entered, 0, worker}, 1000
    worker_ref = Process.monitor(worker)
    :ok = Pristine.Cancellation.cancel(token)
    assert_receive {:DOWN, ^worker_ref, :process, ^worker, _reason}, 1000

    assert [{:error, %Error{type: :cancelled, cause: %Pristine.Error{type: :cancelled}}}] =
             Task.await(consumer)

    refute_receive {:entered, 1, _}, 100
  end
end
