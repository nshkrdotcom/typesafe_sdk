defmodule TypeSafeSDK.OTP.ServerV040Test do
  use ExUnit.Case, async: true

  alias Pristine.Cancellation
  alias TypeSafeSDK.{Error, Response, Test}

  defmodule CrashingTransport do
    @behaviour Pristine.Ports.Transport

    @impl true
    def capabilities(_context),
      do: %{unary_cancellation: :supported, cancellation_cleanup: :supported}

    @impl true
    def send(_request, _context), do: raise("private transport failure")

    @impl true
    def send_cancelable(request, context, cancellation) do
      Kernel.send(Keyword.fetch!(context.transport_opts, :test_pid), {:private_token, cancellation})
      __MODULE__.send(request, context)
    end
  end

  defmodule UnsupportedTransport do
    @behaviour Pristine.Ports.Transport

    @impl true
    def send(_request, _context), do: raise("unsupported transport must not be called")
  end

  defmodule Triage do
    use TypeSafeSDK.OTP.Server

    @impl true
    def init(test_pid), do: {:ok, %{test_pid: test_pid, seen: 0}}

    @impl true
    def handle_call({:classify, state}, from, inner),
      do: classify(from, state, [], inner)

    def handle_call({:classify, state, opts}, from, inner),
      do: classify(from, state, opts, inner)

    @impl true
    def handle_evaluation({:ok, response}, from, inner) do
      GenServer.reply(from, {:ok, Response.values(response)})
      {:noreply, %{inner | seen: inner.seen + 1}}
    end

    def handle_evaluation({:error, %Error{} = error}, from, inner) do
      GenServer.reply(from, {:error, error})
      {:noreply, inner}
    end

    defp classify(from, state, opts, inner) do
      questions = [route: TypeSafeSDK.choice("Route?", billing: nil, support: nil)]
      {:evaluate, {from, state, questions, opts}, inner}
    end
  end

  defmodule Recursive do
    use TypeSafeSDK.OTP.Server

    @impl true
    def init(_), do: {:ok, %{steps: 0}}

    @impl true
    def handle_call(:run, from, state) do
      {:evaluate, {{from, 1}, "first", [continue: TypeSafeSDK.noul("Continue?")]}, state}
    end

    @impl true
    def handle_evaluation({:ok, _response}, {from, 1}, state) do
      request = {{from, 2}, "second", [continue: TypeSafeSDK.noul("Continue?")]}
      {:evaluate, request, %{state | steps: 1}}
    end

    def handle_evaluation({:ok, response}, {from, 2}, state) do
      GenServer.reply(from, {:ok, Response.values(response), state.steps + 1})
      {:noreply, %{state | steps: state.steps + 1}}
    end

    def handle_evaluation({:error, %Error{} = error}, {from, _step}, state) do
      GenServer.reply(from, {:error, error})
      {:noreply, state}
    end
  end

  setup do
    supervisor = start_supervised!({Task.Supervisor, max_children: 8})
    %{supervisor: supervisor}
  end

  test "delegates evaluation asynchronously and returns enriched values", %{
    supervisor: supervisor
  } do
    client = routing_client(self())
    pid = start_triage(client, supervisor, max_in_flight: 2)

    assert {:ok, %{route: :billing}} = GenServer.call(pid, {:classify, "invoice"})
    assert {:ok, %{route: :support}} = GenServer.call(pid, {:classify, "login"})
    assert %{inner: %{seen: 2}, in_flight: 0, max_in_flight: 2} = status_state(pid)
  end

  test "max_in_flight rejects additional work before transport", %{supervisor: supervisor} do
    parent = self()

    client =
      Test.client()
      |> Test.stub_callback(fn request ->
        body = decode_body(request)
        send(parent, {:transport_started, body["state"], self()})

        receive do
          :release -> answer_fixture(body["state"])
        after
          2_000 -> raise "blocked test transport was not released"
        end
      end)

    pid = start_triage(client, supervisor, max_in_flight: 1)
    first = Task.async(fn -> GenServer.call(pid, {:classify, "invoice"}) end)
    assert_receive {:transport_started, "invoice", transport_worker}

    assert status_state(pid) == %{
             module: Triage,
             inner: %{test_pid: self(), seen: 0},
             in_flight: 1,
             max_in_flight: 1
           }

    assert {:error, %Error{type: :runtime_capability}} =
             GenServer.call(pid, {:classify, "login"})

    assert Test.stats(client).total == 1
    send(transport_worker, :release)
    assert {:ok, %{route: :billing}} = Task.await(first)
  end

  test "out-of-order completions retain the correct caller tag", %{supervisor: supervisor} do
    parent = self()

    client =
      Test.client()
      |> Test.stub_callback(fn request ->
        body = decode_body(request)
        send(parent, {:transport_started, body["state"], self()})

        receive do
          :release -> answer_fixture(body["state"])
        after
          2_000 -> raise "blocked test transport was not released"
        end
      end)

    pid = start_triage(client, supervisor, max_in_flight: 2)
    slow = Task.async(fn -> GenServer.call(pid, {:classify, "invoice"}) end)
    fast = Task.async(fn -> GenServer.call(pid, {:classify, "login"}) end)

    workers = receive_workers(%{}, 2)
    send(Map.fetch!(workers, "login"), :release)
    assert {:ok, %{route: :support}} = Task.await(fast)
    send(Map.fetch!(workers, "invoice"), :release)
    assert {:ok, %{route: :billing}} = Task.await(slow)
  end

  test "request options override validated server defaults", %{supervisor: supervisor} do
    parent = self()

    client =
      Test.client()
      |> Test.stub_callback(fn request ->
        body = decode_body(request)
        send(parent, {:observed_model, body["model"]})
        answer_fixture(body["state"])
      end)

    pid =
      start_triage(client, supervisor,
        max_in_flight: 2,
        evaluation_options: [model: "jev-base"]
      )

    assert {:ok, _} = GenServer.call(pid, {:classify, "invoice"})
    assert_receive {:observed_model, "jev-base"}

    assert {:ok, _} =
             GenServer.call(pid, {:classify, "login", [model: "jev-request"]})

    assert_receive {:observed_model, "jev-request"}
  end

  test "invalid per-request options fail before transport", %{supervisor: supervisor} do
    client = routing_client(self())
    pid = start_triage(client, supervisor, max_in_flight: 1)

    assert {:error, %Error{type: :invalid_request}} =
             GenServer.call(pid, {:classify, "invoice", [model: "a", model: "b"]})

    assert Test.stats(client).total == 0
  end

  test "caller cancellation is mirrored into the private request token", %{
    supervisor: supervisor
  } do
    parent = self()
    caller_token = Cancellation.new()

    client =
      Test.client()
      |> Test.stub_callback(fn request ->
        body = decode_body(request)
        send(parent, {:transport_started, body["state"], self()})
        Process.sleep(:infinity)
      end)

    pid = start_triage(client, supervisor, max_in_flight: 1)

    request =
      Task.async(fn ->
        GenServer.call(pid, {:classify, "invoice", [cancellation: caller_token]})
      end)

    assert_receive {:transport_started, "invoice", _worker}
    :ok = Cancellation.cancel(caller_token)
    assert {:error, %Error{type: :cancelled}} = Task.await(request)
    assert Process.alive?(pid)
  end

  test "a saturated caller task supervisor becomes a normalized evaluation error" do
    supervisor = start_supervised!({Task.Supervisor, max_children: 1}, id: :saturated_tasks)
    blocker = Task.Supervisor.async_nolink(supervisor, fn -> Process.sleep(:infinity) end)
    client = routing_client(self())
    pid = start_triage(client, supervisor, max_in_flight: 1)

    assert {:error, %Error{type: :runtime_capability}} =
             GenServer.call(pid, {:classify, "invoice"})

    Task.shutdown(blocker, :brutal_kill)
    assert Process.alive?(pid)
  end

  test "recursive handle_evaluation can launch another bounded evaluation", %{
    supervisor: supervisor
  } do
    client = Test.client() |> Test.stub(continue: {:noul, 0.9})

    pid =
      start_supervised!(
        {Recursive, [client: client, task_supervisor: supervisor, max_in_flight: 1]}
      )

    assert {:ok, %{continue: 0.9}, 2} = GenServer.call(pid, :run)
    assert Test.stats(client).total == 2
  end

  test "server shutdown never cancels a caller-owned cancellation token", %{
    supervisor: supervisor
  } do
    parent = self()
    caller_token = Cancellation.new()

    client =
      Test.client()
      |> Test.stub_callback(fn request ->
        body = decode_body(request)
        send(parent, {:transport_started, body["state"], self()})
        Process.sleep(:infinity)
      end)

    pid = start_triage(client, supervisor, max_in_flight: 1)

    spawn(fn ->
      result =
        try do
          GenServer.call(pid, {:classify, "invoice", [cancellation: caller_token]}, :infinity)
        catch
          :exit, reason -> {:exit, reason}
        end

      send(parent, {:caller_finished, result})
    end)

    assert_receive {:transport_started, "invoice", _worker}
    refute Cancellation.cancelled?(caller_token)
    :ok = GenServer.stop(pid, :normal)
    refute Cancellation.cancelled?(caller_token)
    assert Process.alive?(supervisor)
    assert_receive {:caller_finished, {:exit, _reason}}, 1_000
  end

  test "requires an explicit running task supervisor" do
    Process.flag(:trap_exit, true)
    client = Test.client()

    assert {:error, %Error{type: :configuration}} =
             Triage.start_link(init_arg: self(), client: client, task_supervisor: :not_running)
  end

  @tag :capture_log
  test "transport exceptions become worker-exit errors and cancel the private token", %{
    supervisor: supervisor
  } do
    client =
      TypeSafeSDK.Client.new(
        api_key: "private-test-key",
        transport: CrashingTransport,
        transport_opts: [test_pid: self()],
        retry: false
      )

    pid = start_triage(client, supervisor, max_in_flight: 1)

    assert {:error, %Error{type: :task_exit} = error} =
             GenServer.call(pid, {:classify, "invoice"})

    assert_receive {:private_token, token}
    assert Cancellation.cancelled?(token)
    refute inspect(error) =~ "private transport failure"
    assert Process.alive?(pid)
    assert status_state(pid).in_flight == 0
  end

  test "unsupported cancellation returns a typed error without crashing the server", %{
    supervisor: supervisor
  } do
    client = TypeSafeSDK.Client.new(api_key: "test-key", transport: UnsupportedTransport)
    pid = start_triage(client, supervisor, max_in_flight: 1)

    assert {:error, %Error{type: :runtime_capability}} =
             GenServer.call(pid, {:classify, "invoice"})

    assert Process.alive?(pid)
    assert status_state(pid).in_flight == 0
  end

  defp routing_client(_test_pid) do
    Test.client()
    |> Test.stub_callback(fn request ->
      request |> decode_body() |> Map.fetch!("state") |> answer_fixture()
    end)
  end

  defp start_triage(client, supervisor, opts) do
    options =
      [init_arg: self(), client: client, task_supervisor: supervisor]
      |> Keyword.merge(opts)

    start_supervised!({Triage, options}, id: {Triage, make_ref()})
  end

  defp decode_body(request), do: request.body |> IO.iodata_to_binary() |> Jason.decode!()

  defp answer_fixture("invoice"),
    do: {:answers, [route: {:choice, :billing, 0.9}], [model: "jev-test"]}

  defp answer_fixture(_state),
    do: {:answers, [route: {:choice, :support, 0.9}], [model: "jev-test"]}

  defp receive_workers(workers, 0), do: workers

  defp receive_workers(workers, remaining) do
    receive do
      {:transport_started, state, worker} ->
        receive_workers(Map.put(workers, state, worker), remaining - 1)
    after
      2_000 -> flunk("did not observe all transport workers")
    end
  end

  defp status_state(pid) do
    {:status, _, _, items} = :sys.get_status(pid)

    items
    |> List.last()
    |> Keyword.get_values(:data)
    |> List.flatten()
    |> List.keyfind(~c"State", 0)
    |> elem(1)
  end
end
