defmodule TypeSafeSDK.Test.Transport do
  @moduledoc false
  @behaviour Pristine.Ports.Transport

  alias Pristine.Cancellation
  alias TypeSafeSDK.Test.{ContractError, Fixture, Scenario}

  @impl true
  def capabilities(_context) do
    %{
      unary_cancellation: :supported,
      cancellation_cleanup: :supported
    }
  end

  @impl true
  def send(request, context) do
    pid = Keyword.fetch!(context.transport_opts, :scenario)

    try do
      case Scenario.checkout(pid, request) do
        {:ok, fixture} -> Fixture.respond(fixture, request)
        {:error, message} -> raise ContractError, message: message
      end
    rescue
      error in ContractError ->
        Scenario.failure(pid, error.message)
        reraise error, __STACKTRACE__
    end
  end

  @impl true
  def send_cancelable(request, context, cancellation) do
    {:ok, cancellation} = Cancellation.validate(cancellation)

    if Cancellation.cancelled?(cancellation) do
      {:error, Pristine.Error.cancelled_error()}
    else
      parent = self()

      {worker, monitor} =
        spawn_monitor(fn ->
          result = __MODULE__.send(request, context)
          Kernel.send(parent, {:typesafe_test_transport_result, self(), result})
        end)

      watcher =
        Cancellation.watch(cancellation, fn ->
          Process.exit(worker, :kill)
        end)

      try do
        await_cancelable(worker, monitor, cancellation)
      after
        Cancellation.stop_watcher(watcher)
      end
    end
  end

  defp await_cancelable(worker, monitor, cancellation) do
    receive do
      {:typesafe_test_transport_result, ^worker, result} ->
        Process.demonitor(monitor, [:flush])
        result

      {:DOWN, ^monitor, :process, ^worker, reason} ->
        if Cancellation.cancelled?(cancellation),
          do: {:error, Pristine.Error.cancelled_error()},
          else: {:error, reason}
    end
  end
end
