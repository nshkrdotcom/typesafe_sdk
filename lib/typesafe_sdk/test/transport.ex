defmodule TypeSafeSDK.Test.Transport do
  @moduledoc false
  @behaviour Pristine.Ports.Transport
  alias TypeSafeSDK.Test.{ContractError, Fixture, Scenario}

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
end
