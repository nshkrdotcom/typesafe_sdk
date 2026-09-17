defmodule TypeSafeSDK.Batch do
  @moduledoc """
  Lazy, bounded evaluation using an owned supervisor and unlinked tasks.

  The stream is cold and re-enumerable. Every enumeration owns its supervisor;
  early halt and errors stop remaining tasks. This bounds tasks in this batch,
  not queues in the shared HTTP transport. Ordered evaluation uses bounded
  prefetch windows (`max_pending`, default four times concurrency); one window
  completes before the next starts. Unordered results retain batch_index.
  """
  alias TypeSafeSDK.Batch.Lifecycle
  alias TypeSafeSDK.{Error, Evaluation, Prepared, SystemOneResponse, Telemetry}
  alias TypeSafeSDK.Question.Validation

  @batch_options [
    :max_concurrency,
    :max_pending,
    :ordered,
    :on_error,
    :task_timeout_ms,
    :attempt_timeout_ms
  ]

  @spec stream(TypeSafeSDK.Client.t(), Enumerable.t(), term(), keyword()) :: Enumerable.t()
  def stream(client, states, questions, opts \\ []) do
    {prepared, request_opts, task_opts, on_error, max_pending} = prepare!(questions, opts)

    Stream.resource(
      fn ->
        {:ok, lifecycle} = Lifecycle.start(self(), task_opts[:max_concurrency])
        supervisor = Lifecycle.supervisor(lifecycle)
        indexed = Stream.with_index(states)
        worker = fn input -> evaluate_input(client, input, prepared, request_opts) end
        cancellation = Keyword.get(request_opts, :cancellation)
        stream = task_stream(supervisor, indexed, worker, task_opts, max_pending, cancellation)
        {lifecycle, {:new, stream}}
      end,
      &next/1,
      &close/1
    )
    |> Stream.map(&result(&1, on_error))
  end

  @spec many(TypeSafeSDK.Client.t(), Enumerable.t(), term(), keyword()) :: list()
  def many(client, states, questions, opts \\ []),
    do: client |> stream(states, questions, opts) |> Enum.to_list()

  defp prepare!(questions, opts) do
    unless is_list(opts) and Keyword.keyword?(opts),
      do: raise(Error.invalid_request(["options"], "must be a keyword list"))

    batch = Keyword.take(opts, @batch_options)
    request = Keyword.drop(opts, @batch_options)
    Validation.unwrap!(as_result(Validation.options(batch, @batch_options)))
    max_concurrency = Keyword.get(batch, :max_concurrency, 8)
    max_pending = Keyword.get(batch, :max_pending)
    task_timeout = Keyword.get(batch, :task_timeout_ms, 40_000)
    ordered = Keyword.get(batch, :ordered, true)
    on_error = Keyword.get(batch, :on_error, :collect)

    check!(
      is_integer(max_concurrency) and max_concurrency in 1..1024,
      "max_concurrency",
      "must be in 1..1024"
    )

    max_pending = if is_nil(max_pending), do: max_concurrency * 4, else: max_pending

    check!(
      is_integer(max_pending) and max_pending >= max_concurrency and max_pending <= 10_000,
      "max_pending",
      "must be at least max_concurrency and at most 10000"
    )

    check!(
      is_integer(task_timeout) and task_timeout > 0,
      "task_timeout_ms",
      "must be a positive integer"
    )

    check!(is_boolean(ordered), "ordered", "must be a boolean")
    check!(on_error in [:collect, :raise], "on_error", "must be :collect or :raise")
    request = attempt_timeout!(request, Keyword.get(batch, :attempt_timeout_ms))
    Validation.unwrap!(as_result(Evaluation.validate_options(request)))
    prepared = Prepared.new!(questions)

    {prepared, request,
     [
       max_concurrency: max_concurrency,
       ordered: ordered,
       timeout: task_timeout,
       on_timeout: :kill_task,
       zip_input_on_exit: true,
       shutdown: :brutal_kill
     ], on_error, max_pending}
  end

  defp task_stream(supervisor, indexed, worker, task_opts, max_pending, cancellation) do
    if task_opts[:ordered] do
      # async_stream's active-task bound alone does not bound its ordered
      # completion buffer. Finite windows provide that bound without replacing
      # OTP's task timeout or monitor machinery. The inner source checks the
      # shared Pristine token every time async_stream asks for another task.
      indexed
      |> Stream.chunk_every(max_pending)
      |> Stream.flat_map(fn window ->
        source = cancellation_aware(window, cancellation)
        Task.Supervisor.async_stream_nolink(supervisor, source, worker, task_opts)
      end)
    else
      source = cancellation_aware(indexed, cancellation)
      Task.Supervisor.async_stream_nolink(supervisor, source, worker, task_opts)
    end
  end

  defp cancellation_aware(stream, nil), do: stream

  defp cancellation_aware(stream, cancellation) do
    {:ok, cancellation} = Pristine.Cancellation.validate(cancellation)
    Stream.take_while(stream, fn _item -> not Pristine.Cancellation.cancelled?(cancellation) end)
  end

  defp evaluate_input(client, {state, index}, prepared, request_opts) do
    started = System.monotonic_time(:microsecond)

    result =
      try do
        Evaluation.run(client, state, prepared, request_opts)
      catch
        kind, _reason ->
          # Do not let OTP's Task crash report print state-bearing arguments or
          # exception reasons. Untrappable external exits are handled by result/2.
          Telemetry.cancelled(index, :task_exit)

          {:error,
           %Error{
             type: :task_exit,
             message: "Batch evaluation worker failed",
             details: %{
               scope: :batch,
               kind: kind,
               elapsed_ms: (System.monotonic_time(:microsecond) - started) / 1000
             }
           }}
      end

    {index, result}
  end

  defp attempt_timeout!(request, nil), do: request

  defp attempt_timeout!(request, value) do
    check!(is_integer(value) and value > 0, "attempt_timeout_ms", "must be a positive integer")

    check!(
      not Keyword.has_key?(request, :timeout_ms) and not Keyword.has_key?(request, :timeout),
      "attempt_timeout_ms",
      "cannot be combined with timeout or timeout_ms"
    )

    Keyword.put(request, :timeout_ms, value)
  end

  defp as_result(:ok), do: {:ok, :ok}
  defp as_result(error), do: error
  defp check!(true, _, _), do: :ok
  defp check!(false, key, reason), do: raise(Error.invalid_request(["options", key], reason))

  defp next({supervisor, {:new, stream}}) do
    advance(supervisor, Enumerable.reduce(stream, {:cont, nil}, fn item, _ -> {:suspend, item} end))
  end

  defp next({supervisor, {:continuation, continuation}}),
    do: advance(supervisor, continuation.({:cont, nil}))

  defp next({supervisor, :done}), do: {:halt, {supervisor, :done}}

  defp advance(supervisor, {:suspended, item, continuation}),
    do: {[item], {supervisor, {:continuation, continuation}}}

  defp advance(supervisor, {done, _}) when done in [:done, :halted],
    do: {:halt, {supervisor, :done}}

  defp close({supervisor, state}) do
    case state do
      {:continuation, continuation} -> continuation.({:halt, nil})
      _ -> :ok
    end
  after
    stop_lifecycle(supervisor)
  end

  defp stop_lifecycle(lifecycle) do
    if Process.alive?(lifecycle), do: GenServer.stop(lifecycle, :normal, :infinity)
    :ok
  catch
    :exit, {:noproc, _} -> :ok
    :exit, {:normal, _} -> :ok
  end

  defp result({:ok, {index, {:ok, %SystemOneResponse{} = response}}}, _),
    do: {:ok, %{response | batch_index: index}}

  defp result({:ok, {index, {:error, %Error{} = error}}}, policy),
    do: failure(%{error | details: Map.put(error.details, :batch_index, index)}, policy)

  defp result({:exit, {{_state, index}, reason}}, policy) do
    type = if reason == :timeout, do: :timeout, else: :task_exit
    Telemetry.cancelled(index, type)
    # Task exits may contain customer state in stack frames. Never copy the reason.
    error = %Error{
      type: type,
      message: "Batch evaluation #{index} #{type}",
      details: %{scope: :batch, batch_index: index}
    }

    failure(error, policy)
  end

  defp failure(error, :collect), do: {:error, error}
  defp failure(error, :raise), do: raise(error)
end
