defmodule TypeSafeSDK.Test do
  @moduledoc """
  Explicit, isolated application fixtures at the Pristine transport seam.

  These helpers do not replace serialization, retry classification, decoding or
  semantic validation. The configured transport can never call the live API.
  A scenario monitors its creating process and can be shared explicitly with
  child tasks. Call `verify!/1` before the owner exits, and `close/1` when done.

      client = TypeSafeSDK.Test.client()
      client = TypeSafeSDK.Test.stub(client, urgent: {:noul, 0.9})
      result = TypeSafeSDK.evaluate!(client, "synthetic example", urgent: TypeSafeSDK.noul("Urgent?"))
      TypeSafeSDK.Test.verify!(client)
      TypeSafeSDK.Test.close(client)

  Default retries are disabled. Enable the real retry policy explicitly when
  using `stub_sequence/2`. Request history is bounded (default 1000) and contains
  the actual serialized request; use synthetic data and test credentials only.
  """
  alias TypeSafeSDK.Client
  alias TypeSafeSDK.Test.{ContractError, Scenario, Transport}

  @spec client(keyword()) :: Client.t()
  def client(opts \\ []) do
    limit = Keyword.get(opts, :history_limit, 1000)

    unless is_integer(limit) and limit in 1..10_000,
      do: raise(ArgumentError, "history_limit must be in 1..10000")

    {:ok, scenario} = Scenario.start(self(), limit)

    try do
      opts
      |> Keyword.drop([:history_limit, :transport, :transport_opts])
      |> Keyword.put_new(:api_key, "typesafe-test-key")
      |> Keyword.put_new(:base_url, "http://typesafe.test.invalid")
      |> Keyword.put_new(:retry, false)
      |> Keyword.put(:transport, Transport)
      |> Keyword.put(:transport_opts, scenario: scenario)
      |> Client.new()
      |> isolate_runtime(scenario)
    rescue
      error ->
        GenServer.stop(scenario)
        reraise error, __STACKTRACE__
    end
  end

  @spec stub(Client.t(), map() | list(), keyword()) :: Client.t()
  def stub(client, answers, opts \\ []), do: install(client, {:answers, answers, opts})

  @doc "Build a fixture from the actual request, for state-dependent or synchronized application tests."
  def stub_callback(client, fun) when is_function(fun, 1), do: install(client, {:callback, fun})

  @spec stub_models(Client.t(), list(), keyword()) :: Client.t()
  def stub_models(client, models, opts \\ []), do: install(client, {:models, models, opts})

  @spec stub_http_error(Client.t(), integer(), keyword()) :: Client.t()
  def stub_http_error(client, status, opts \\ []), do: install(client, {:http_error, status, opts})

  @spec stub_transport_error(Client.t(), term()) :: Client.t()
  def stub_transport_error(client, reason), do: install(client, {:transport_error, reason})

  @doc "Raw response escape hatch for testing malformed or future response contracts."
  def stub_response(client, body, opts \\ []), do: install(client, {:response, body, opts})

  @doc """
  Finite request/attempt sequence. Exhaustion fails; `verify!/1` checks consumption.

  Entries: `{:answers, specs, opts}`, `{:models, models, opts}`,
  `{:http_error, status, opts}`, `{:transport_error, reason}`,
  `{:response, raw_body, opts}`. The first, second, third and fifth accept omitted opts.
  """
  @spec stub_sequence(Client.t(), list()) :: Client.t()
  def stub_sequence(client, fixtures) when is_list(fixtures) do
    if length(fixtures) > 10_000, do: raise(ArgumentError, "at most 10000 sequence entries")
    :ok = Scenario.sequence(scenario!(client), fixtures)
    client
  end

  @spec requests(Client.t()) :: list()
  def requests(client), do: stats(client).requests
  @spec stats(Client.t()) :: map()
  def stats(client), do: Scenario.inspect_state(scenario!(client))

  @spec verify!(Client.t()) :: :ok
  def verify!(client) do
    stats = stats(client)

    cond do
      stats.failures != [] ->
        raise ContractError, message: Enum.join(stats.failures, "; ")

      stats.pending > 0 ->
        raise ContractError, message: "#{stats.pending} TypeSafe sequence entries were not consumed"

      true ->
        :ok
    end
  end

  @spec close(Client.t()) :: :ok
  def close(client) do
    pid = scenario!(client)
    if Process.alive?(pid), do: GenServer.stop(pid, :normal)
    :ok
  catch
    :exit, {:noproc, _} -> :ok
  end

  defp isolate_runtime(client, scenario) do
    opts = Scenario.runtime_opts(scenario)

    context = %{
      client.context
      | rate_limit_opts: opts.rate_limit_opts,
        circuit_breaker_opts: opts.circuit_breaker_opts
    }

    %{client | context: context, pristine_client: Pristine.Client.from_context(context)}
  end

  defp install(client, fixture) do
    :ok = Scenario.install(scenario!(client), fixture)
    client
  end

  defp scenario!(%Client{transport: Transport, transport_opts: opts}),
    do: Keyword.fetch!(opts, :scenario)

  defp scenario!(_), do: raise(ArgumentError, "expected a TypeSafeSDK.Test client")
end
