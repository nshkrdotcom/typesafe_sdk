defmodule TypeSafeSDK.Test.Scenario do
  @moduledoc false
  use GenServer

  def start(owner, limit), do: GenServer.start(__MODULE__, {owner, limit})
  def install(pid, fixture), do: GenServer.call(pid, {:install, fixture})
  def sequence(pid, fixtures), do: GenServer.call(pid, {:sequence, fixtures})
  def checkout(pid, request), do: GenServer.call(pid, {:checkout, request})
  def runtime_opts(pid), do: GenServer.call(pid, :runtime_opts)
  def inspect_state(pid), do: GenServer.call(pid, :inspect)
  def failure(pid, message), do: GenServer.call(pid, {:failure, message})

  @impl true
  def init({owner, limit}) do
    {:ok,
     %{
       owner_ref: Process.monitor(owner),
       rate_limit_registry: registry(Foundation.RateLimit.BackoffWindow),
       circuit_breaker_registry: registry(Foundation.CircuitBreaker.Registry),
       limit: limit,
       history: :queue.new(),
       size: 0,
       total: 0,
       default: :unset,
       sequence: nil,
       failures: []
     }}
  end

  @impl true
  def handle_call({:install, fixture}, _, state),
    do: {:reply, :ok, %{state | default: fixture, sequence: nil}}

  def handle_call({:sequence, fixtures}, _, state),
    do: {:reply, :ok, %{state | default: :unset, sequence: fixtures}}

  def handle_call({:checkout, request}, _, state) do
    state = capture(state, request)

    case state.sequence do
      [fixture | rest] ->
        {:reply, {:ok, fixture}, %{state | sequence: rest}}

      [] ->
        {:reply, {:error, "TypeSafe test sequence is exhausted"}, state}

      nil when state.default == :unset ->
        {:reply, {:error, "No TypeSafe test response was configured"}, state}

      nil ->
        {:reply, {:ok, state.default}, state}
    end
  end

  def handle_call({:failure, message}, _, state),
    do: {:reply, :ok, %{state | failures: Enum.take([message | state.failures], 100)}}

  def handle_call(:runtime_opts, _, state) do
    {:reply,
     %{
       rate_limit_opts: [registry: state.rate_limit_registry],
       circuit_breaker_opts: [registry: state.circuit_breaker_registry]
     }, state}
  end

  def handle_call(:inspect, _, state) do
    info = %{
      requests: :queue.to_list(state.history),
      total: state.total,
      dropped: state.total - state.size,
      pending: length(state.sequence || []),
      failures: Enum.reverse(state.failures)
    }

    {:reply, info, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{owner_ref: ref} = state),
    do: {:stop, :normal, state}

  defp registry(module) do
    # Foundation 0.2.2 explicit tables have no heir and expire with this scenario.
    module.new_registry()
  end

  defp capture(state, request) do
    history = :queue.in(request, state.history)

    if state.size == state.limit do
      {{:value, _}, history} = :queue.out(history)
      %{state | history: history, total: state.total + 1}
    else
      %{state | history: history, total: state.total + 1, size: state.size + 1}
    end
  end
end
