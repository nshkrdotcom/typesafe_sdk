defmodule TypeSafeSDK.BatchTest do
  use ExUnit.Case, async: true
  alias TypeSafeSDK.{Error, Test}
  defp questions, do: [q: TypeSafeSDK.noul("Q?")]

  test "preparation and shared-option failures occur before spawning requests" do
    client = Test.client()
    assert_raise Error, fn -> TypeSafeSDK.evaluate_many(client, ["x"], [], on_error: :collect) end

    for opts <- [
          [max_concurrency: 0],
          [ordered: :yes],
          [task_timeout_ms: :infinity],
          [on_error: :ignore],
          [attempt_timeout_ms: 5, timeout_ms: 3]
        ] do
      assert_raise Error, fn -> TypeSafeSDK.evaluate_many(client, ["x"], questions(), opts) end
    end

    assert Test.requests(client) == []
  end

  test "stream is cold, reusable, and records one result per state including validation errors" do
    client = Test.client() |> Test.stub(q: {:noul, 0.9})
    stream = TypeSafeSDK.evaluate_stream(client, ["one", self(), "three"], questions())
    assert Test.requests(client) == []
    assert [{:ok, a}, {:error, error}, {:ok, c}] = Enum.to_list(stream)
    assert a.batch_index == 0
    assert c.batch_index == 2
    assert error.type == :invalid_request
    assert error.details.batch_index == 1
    assert length(Enum.to_list(stream)) == 3
    assert Test.stats(client).total == 4
  end

  test "concurrency is bounded and early halt kills remaining owned tasks" do
    owner = self()

    client =
      Test.client()
      |> Test.stub_callback(fn request ->
        state = Jason.decode!(request.body)["state"]
        send(owner, {:entered, state, self()})

        receive do
          :release -> {:answers, [q: {:noul, 0.9}]}
        after
          2000 -> raise "test synchronization was not released"
        end
      end)

    consumer =
      Task.async(fn ->
        client
        |> TypeSafeSDK.evaluate_stream(Stream.iterate(0, &(&1 + 1)), questions(),
          max_concurrency: 2
        )
        |> Enum.take(1)
      end)

    assert_receive {:entered, a, pa}, 1000
    assert_receive {:entered, b, pb}, 1000
    assert Enum.sort([a, b]) == [0, 1]
    refute_receive {:entered, _, _}, 30
    {first, other} = if a == 0, do: {pa, pb}, else: {pb, pa}
    ref = Process.monitor(other)
    send(first, :release)
    assert [{:ok, %{batch_index: 0}}] = Task.await(consumer)
    assert_receive {:DOWN, ^ref, :process, ^other, _}, 1000
  end

  test "per-state timeout preserves index and never reports the raw state as an exit reason" do
    client =
      Test.client()
      |> Test.stub_callback(fn _request ->
        receive do
          :never -> {:answers, [q: {:noul, 0.9}]}
        end
      end)

    assert [{:error, error}] =
             TypeSafeSDK.evaluate_many(client, ["private-state"], questions(), task_timeout_ms: 30)

    assert error.type == :timeout
    assert error.details == %{scope: :batch, batch_index: 0}
    refute inspect(error) =~ "private-state"
    refute Error.retryable?(error)
  end

  test "unordered results retain association with input indexes" do
    owner = self()

    client =
      Test.client()
      |> Test.stub_callback(fn request ->
        index = Jason.decode!(request.body)["state"]
        send(owner, {:ready, index, self()})

        receive do
          :release -> {:answers, [q: {:noul, 0.9}]}
        end
      end)

    consumer =
      Task.async(fn ->
        TypeSafeSDK.evaluate_stream(client, [0, 1], questions(), ordered: false, max_concurrency: 2)
        |> Enum.map(fn result ->
          send(owner, {:result, result})
          result
        end)
      end)

    assert_receive {:ready, a, pa}, 1000
    assert_receive {:ready, b, pb}, 1000
    assert Enum.sort([a, b]) == [0, 1]
    {p0, p1} = if a == 0, do: {pa, pb}, else: {pb, pa}
    send(p1, :release)
    assert_receive {:result, {:ok, %{batch_index: 1}}}, 1000
    send(p0, :release)
    assert [{:ok, %{batch_index: 1}}, {:ok, %{batch_index: 0}}] = Task.await(consumer)
  end

  test "caller death cleans the supervisor and its tasks" do
    owner = self()

    client =
      Test.client()
      |> Test.stub_callback(fn _request ->
        send(owner, {:waiting, self()})

        receive do
          :never -> {:answers, [q: {:noul, 1.0}]}
        end
      end)

    consumer =
      spawn(fn -> TypeSafeSDK.evaluate_many(client, [0, 1], questions(), max_concurrency: 2) end)

    assert_receive {:waiting, one}, 1000
    assert_receive {:waiting, two}, 1000
    refs = Enum.map([one, two], &Process.monitor/1)
    Process.exit(consumer, :kill)
    for ref <- refs, do: assert_receive({:DOWN, ^ref, :process, _, _}, 1000)
  end

  test "on_error raise uses the normalized SDK error, and attempts use millisecond option" do
    client = Test.client() |> Test.stub_http_error(401)

    assert_raise Error, fn ->
      TypeSafeSDK.evaluate_many(client, ["x"], questions(), on_error: :raise)
    end

    client = Test.stub(client, q: {:noul, 0.8})

    assert [{:ok, _}] =
             TypeSafeSDK.evaluate_many(client, ["x"], questions(), attempt_timeout_ms: 777)

    assert List.last(Test.requests(client)).metadata.timeout == 777
  end

  test "test scenario lifetime is monitored even after a normal owner exit" do
    parent = self()

    owner =
      spawn(fn ->
        client = Test.client()
        send(parent, {:client, client})

        receive do
          :finish -> :ok
        end
      end)

    assert_receive {:client, client}
    scenario = client.transport_opts[:scenario]
    ref = Process.monitor(scenario)
    send(owner, :finish)
    assert_receive {:DOWN, ^ref, :process, ^scenario, :normal}, 1000
    assert Test.close(client) == :ok
  end

  test "stream cleanup does not leak lifecycle EXIT messages into a trapping caller" do
    previous = Process.flag(:trap_exit, true)

    try do
      client = Test.client() |> Test.stub(q: {:noul, 0.8})
      assert [{:ok, _}] = TypeSafeSDK.evaluate_many(client, ["x"], questions())
      refute_receive {:EXIT, _, _}, 30
    after
      Process.flag(:trap_exit, previous)
    end
  end

  test "an exited worker becomes a per-input error instead of killing the caller" do
    client = Test.client() |> Test.stub_callback(fn _ -> exit(:kill) end)

    assert [{:error, %Error{} = error}] =
             TypeSafeSDK.evaluate_many(client, ["x"], questions(), max_concurrency: 1)

    # A transport/runtime may normalize the exit; otherwise the batch owns it.
    assert error.type in [:task_exit, :connection]
    assert error.details.batch_index == 0
  end

  test "ordered prefetch and completed-result buffering cannot run past the declared window" do
    owner = self()

    states =
      Stream.map(0..100, fn index ->
        send(owner, {:pulled, index})
        index
      end)

    client =
      Test.client()
      |> Test.stub_callback(fn request ->
        index = Jason.decode!(request.body)["state"]

        if index == 0 do
          send(owner, {:blocked_first, self()})

          receive do
            :release -> :ok
          end
        end

        {:answers, [q: {:noul, 0.9}]}
      end)

    consumer =
      Task.async(fn ->
        TypeSafeSDK.evaluate_stream(client, states, questions(),
          max_concurrency: 2,
          max_pending: 3,
          ordered: true
        )
        |> Enum.take(1)
      end)

    for index <- 0..2, do: assert_receive({:pulled, ^index}, 1000)
    assert_receive {:blocked_first, first}, 1000
    refute_receive {:pulled, 3}, 50
    send(first, :release)
    assert [{:ok, %{batch_index: 0}}] = Task.await(consumer)
    refute_receive {:pulled, 3}, 30

    assert_raise Error, fn ->
      TypeSafeSDK.evaluate_stream(client, [1], questions(), max_concurrency: 2, max_pending: 1)
    end
  end
end
