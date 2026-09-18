Code.require_file("support/live.exs", __DIR__)

alias TypeSafeSDK.Examples.Live
alias TypeSafeSDK.Error

defmodule TypeSafeSDK.Examples.LiveOTPServer do
  use TypeSafeSDK.OTP.Server

  alias TypeSafeSDK.{Error, Response}

  @impl true
  def init(_init_arg), do: {:ok, %{completed: 0, recursive_steps: 0}}

  @impl true
  def handle_call({:classify, correlation, state, opts}, from, inner) do
    questions = [
      route:
        TypeSafeSDK.choice("Which support route best matches this request?", [
          {:billing, "Charges, invoices, and refunds"},
          {:technical, "Product failures and integrations"},
          {:sales, "Plans and purchasing"}
        ])
    ]

    tag = {:classify, from, correlation}
    {:evaluate, {tag, state, questions, opts}, inner}
  end

  def handle_call({:recursive, correlation, state}, from, inner) do
    questions = [
      area:
        TypeSafeSDK.choice("Which broad area best matches this request?", [
          {:billing, "Charges, invoices, and refunds"},
          {:technical, "Product failures and integrations"}
        ])
    ]

    # Explicit bounds are carried in the opaque tag: at most two levels and two
    # requests for this workflow instance.
    tag = {:recursive_broad, from, correlation, state, 1, 2, 2}
    {:evaluate, {tag, state, questions, [timeout_ms: 10_000]}, inner}
  end

  def handle_call(:status, _from, inner), do: {:reply, inner, inner}

  @impl true
  def handle_evaluation({:ok, response}, {:classify, from, correlation}, inner) do
    reply = {:ok, correlation, Response.values(response), Response.metadata(response)}
    GenServer.reply(from, reply)
    {:noreply, %{inner | completed: inner.completed + 1}}
  end

  def handle_evaluation(
        {:ok, response},
        {:recursive_broad, from, correlation, state, depth, max_depth, remaining},
        inner
      ) do
    area = response |> Response.values() |> Map.fetch!(:area)
    broad_metadata = Response.metadata(response)

    if depth < max_depth and remaining > 1 do
      options =
        case area do
          :billing ->
            [
              {:invoice, "Correct or explain an invoice"},
              {:refund, "Return or reverse a charge"}
            ]

          :technical ->
            [
              {:incident, "Service outage or broken behavior"},
              {:integration, "Configuration or integration issue"}
            ]
        end

      questions = [detail: TypeSafeSDK.choice("Which narrower workflow best matches?", options)]

      tag =
        {:recursive_detail, from, correlation, area, depth + 1, max_depth, remaining - 1,
         broad_metadata}

      {:evaluate, {tag, state, questions, [timeout_ms: 9_000]},
       %{inner | recursive_steps: inner.recursive_steps + 1}}
    else
      GenServer.reply(from, {:ok, correlation, %{path: [area], requests: 1}, [broad_metadata]})
      {:noreply, %{inner | completed: inner.completed + 1}}
    end
  end

  def handle_evaluation(
        {:ok, response},
        {:recursive_detail, from, correlation, area, depth, max_depth, remaining, broad_metadata},
        inner
      ) do
    detail = response |> Response.values() |> Map.fetch!(:detail)

    result = %{
      path: [area, detail],
      depth: depth,
      max_depth: max_depth,
      requests_used: 2,
      requests_remaining: remaining - 1
    }

    GenServer.reply(from, {:ok, correlation, result, [broad_metadata, Response.metadata(response)]})
    {:noreply, %{inner | completed: inner.completed + 1, recursive_steps: inner.recursive_steps + 1}}
  end

  def handle_evaluation({:error, %Error{} = error}, tag, inner) do
    {from, correlation} = caller(tag)
    GenServer.reply(from, {:error, correlation, error})
    {:noreply, inner}
  end

  defp caller({:classify, from, correlation}), do: {from, correlation}

  defp caller({:recursive_broad, from, correlation, _state, _depth, _max_depth, _remaining}),
    do: {from, correlation}

  defp caller(
         {:recursive_detail, from, correlation, _area, _depth, _max_depth, _remaining, _metadata}
       ),
       do: {from, correlation}
end

client = Live.client()
Live.show_configuration(client)

{:ok, task_supervisor} = Task.Supervisor.start_link(max_children: 4)

{:ok, server} =
  TypeSafeSDK.Examples.LiveOTPServer.start_link(
    client: client,
    task_supervisor: task_supervisor,
    max_in_flight: 3,
    evaluation_options: [
      timeout_ms: 12_000,
      retry: false,
      telemetry_metadata: %{example: "live-otp-server", source: "server-default"}
    ]
  )

try do
  owner = self()
  caller_token = Pristine.Cancellation.new()

  requests = [
    {"caller-a", "Please resend the invoice from last month.", []},
    {"caller-b", "Every production API request is failing.",
     [
       timeout_ms: 10_000,
       cancellation: caller_token,
       telemetry_metadata: %{example: "live-otp-server", source: "per-request"}
     ]}
  ]

  tasks =
    Enum.map(requests, fn {correlation, state, opts} ->
      Task.async(fn ->
        result = GenServer.call(server, {:classify, correlation, state, opts}, 20_000)
        send(owner, {:otp_example_completed, correlation, result})
        result
      end)
    end)

  completed =
    for _ <- requests do
      receive do
        {:otp_example_completed, correlation, result} -> {correlation, result}
      after
        20_000 -> raise "Timed out waiting for simultaneous OTP example callers"
      end
    end

  Enum.each(tasks, &Task.await(&1, 1_000))

  safe_completed =
    Enum.map(completed, fn
      {correlation, {:ok, ^correlation, values, metadata}} ->
        %{correlation: correlation, result: :ok, values: values, metadata: metadata}

      {correlation, {:error, ^correlation, %Error{} = error}} ->
        Live.show("OTP request failure", %{correlation: correlation, metadata: Error.metadata(error)})
        raise error
    end)

  Live.show("Simultaneous OTP callers (completion order is not assumed)", safe_completed)

  if Pristine.Cancellation.cancelled?(caller_token) do
    raise "OTP wrapper unexpectedly cancelled the caller-owned token"
  end

  Live.show("Caller-token ownership after completion", %{
    caller_token_cancelled: false,
    wrapper_behavior:
      "The server used a private worker token and only watched the caller token; private cleanup did not mutate caller ownership."
  })

  recursive =
    GenServer.call(
      server,
      {:recursive, "recursive-1", "A duplicate charge appeared while the API integration was failing."},
      25_000
    )

  case recursive do
    {:ok, "recursive-1", result, metadata} ->
      Live.show("Bounded recursive workflow launched from handle_evaluation/3", %{
        correlation: "recursive-1",
        result: result,
        response_metadata: metadata
      })

    {:error, "recursive-1", %Error{} = error} ->
      Live.show("Recursive OTP request failure", Error.metadata(error))
      raise error
  end

  Live.show("Application-owned server status", GenServer.call(server, :status))

  IO.puts("""
The wrapper is configured with max_in_flight: 3 and a caller-owned Task.Supervisor.
Per-request options override matching server-level evaluation options. A fast live service may
never naturally saturate the server, so deterministic overload assertions remain in ExUnit instead
of forcing latency. Opaque correlation values are returned with each result; callers must not infer
identity from completion order.
""")
after
  if Process.alive?(server), do: GenServer.stop(server, :normal, 5_000)
  if Process.alive?(task_supervisor), do: Supervisor.stop(task_supervisor, :normal, 5_000)
end
