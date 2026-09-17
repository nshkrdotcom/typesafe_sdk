defmodule TypeSafeSDK.Batch.Lifecycle do
  @moduledoc false
  use GenServer

  def start(owner, concurrency), do: GenServer.start(__MODULE__, {owner, concurrency})
  def supervisor(owner), do: GenServer.call(owner, :supervisor)

  @impl true
  def init({owner, concurrency}) do
    ref = Process.monitor(owner)
    {:ok, supervisor} = Task.Supervisor.start_link(max_children: concurrency)
    {:ok, %{owner_ref: ref, supervisor: supervisor}}
  end

  @impl true
  def handle_call(:supervisor, _, state), do: {:reply, state.supervisor, state}

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{owner_ref: ref} = state),
    do: {:stop, :normal, state}

  @impl true
  def terminate(_reason, state) do
    if Process.alive?(state.supervisor), do: Supervisor.stop(state.supervisor, :normal, :infinity)
    :ok
  end
end
