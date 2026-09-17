defmodule TypeSafeSDK.OTP.Server do
  @moduledoc """
  Bounded OTP facade for asynchronous TypeSafe evaluations inside a GenServer.

  `use TypeSafeSDK.OTP.Server` keeps ordinary GenServer callbacks in the caller
  module and adds one callback, `handle_evaluation/3`. Return
  `{:evaluate, {tag, state, questions}, inner_state}` (or the four-element form
  with per-request options) from a callback to start an evaluation without
  blocking the server. The eventual `{:ok, response}` / `{:error, error}` result
  is delivered to `handle_evaluation/3` with the same opaque tag.

  This module deliberately does **not** start a global supervisor or own an HTTP
  runtime. Callers provide a `Task.Supervisor` from their application tree and a
  normal `TypeSafeSDK.Client`. `max_in_flight` bounds pending evaluations for the
  server. TypeSafeSDK still delegates HTTP, retries and physical cancellation to
  Pristine.

  The wrapper scopes every request with its own private `Pristine.Cancellation`
  token. When the caller supplies a cancellation token, a temporary watcher mirrors
  caller cancellation into the private token without mutating caller-owned state.
  On server shutdown the private token is cancelled before the local task is stopped.
  """

  use GenServer

  alias TypeSafeSDK.{Client, Error, Evaluation}

  @server_options [:client, :task_supervisor, :max_in_flight, :evaluation_options, :init_arg]
  @genserver_options [:name, :timeout, :debug, :spawn_opt, :hibernate_after]

  @typedoc "An opaque correlation term returned unchanged to `handle_evaluation/3`."
  @type tag :: term()

  @typedoc "A request started by a callback without blocking the server."
  @type evaluation_request ::
          {tag(), term(), term()}
          | {tag(), term(), term(), keyword()}

  @typedoc "Return values accepted from asynchronous delegated callbacks."
  @type async_result(state) ::
          {:evaluate, evaluation_request(), state}
          | {:noreply, state}
          | {:noreply, state, timeout() | :hibernate | {:continue, term()}}
          | {:stop, term(), state}

  @typedoc "Return values accepted from `handle_call/3`."
  @type call_result(state) ::
          async_result(state)
          | {:reply, term(), state}
          | {:reply, term(), state, timeout() | :hibernate | {:continue, term()}}
          | {:stop, term(), term(), state}

  @callback init(term()) ::
              {:ok, term()}
              | {:ok, term(), timeout() | :hibernate | {:continue, term()}}
              | {:stop, term()}
              | :ignore
  @callback handle_evaluation({:ok, term()} | {:error, term()}, tag(), term()) ::
              async_result(term())
  @callback handle_call(term(), GenServer.from(), term()) :: call_result(term())
  @callback handle_cast(term(), term()) :: async_result(term())
  @callback handle_info(term(), term()) :: async_result(term())
  @callback handle_continue(term(), term()) :: async_result(term())
  @callback terminate(term(), term()) :: term()
  @callback code_change(term() | {:down, term()}, term(), term()) ::
              {:ok, term()} | {:error, term()}

  @optional_callbacks handle_call: 3,
                      handle_cast: 2,
                      handle_info: 2,
                      handle_continue: 2,
                      terminate: 2,
                      code_change: 3

  defmacro __using__(_opts) do
    quote do
      alias TypeSafeSDK.OTP.Server

      @behaviour Server

      def start_link(opts), do: Server.start_link(__MODULE__, opts)

      def child_spec(opts) do
        %{
          id: Keyword.get(opts, :id, __MODULE__),
          start: {__MODULE__, :start_link, [Keyword.delete(opts, :id)]},
          type: :worker,
          restart: :permanent,
          shutdown: 5_000
        }
      end

      def handle_info(_message, state), do: {:noreply, state}

      defoverridable start_link: 1, child_spec: 1, handle_info: 2
    end
  end

  @doc """
  Start a wrapped module.

  Required options are `:client` and `:task_supervisor`. Optional wrapper options
  are `:init_arg`, `:max_in_flight` (default 32), and `:evaluation_options`.
  Standard GenServer start options such as `:name` are also accepted.
  """
  @spec start_link(module(), keyword()) :: GenServer.on_start()
  def start_link(module, opts) when is_atom(module) and is_list(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError, "OTP server options must be a keyword list"
    end

    allowed = @server_options ++ @genserver_options
    unknown = Keyword.keys(opts) -- allowed

    if unknown != [] do
      raise ArgumentError, "unknown TypeSafeSDK.OTP.Server options: #{inspect(Enum.uniq(unknown))}"
    end

    server_opts = Keyword.take(opts, @server_options)
    genserver_opts = Keyword.take(opts, @genserver_options)
    GenServer.start_link(__MODULE__, {module, server_opts}, genserver_opts)
  end

  @impl GenServer
  def init({module, opts}) do
    with {:ok, client} <- client(opts),
         {:ok, task_supervisor} <- task_supervisor(opts),
         {:ok, max_in_flight} <- max_in_flight(opts),
         {:ok, evaluation_options} <- evaluation_options(opts) do
      Process.flag(:trap_exit, true)
      init_arg = Keyword.get(opts, :init_arg)

      case module.init(init_arg) do
        {:ok, inner} ->
          {:ok, wrap(module, inner, client, task_supervisor, max_in_flight, evaluation_options)}

        {:ok, inner, extra} ->
          wrapped = wrap(module, inner, client, task_supervisor, max_in_flight, evaluation_options)
          {:ok, wrapped, extra}

        other ->
          other
      end
    else
      {:error, error} -> {:stop, error}
    end
  end

  @impl GenServer
  def handle_call(request, from, state) do
    if function_exported?(state.module, :handle_call, 3) do
      state.module.handle_call(request, from, state.inner) |> route(state)
    else
      {:reply, {:error, :unsupported_call}, state}
    end
  end

  @impl GenServer
  def handle_cast(request, state) do
    if function_exported?(state.module, :handle_cast, 2) do
      state.module.handle_cast(request, state.inner) |> route(state)
    else
      {:noreply, state}
    end
  end

  @impl GenServer
  def handle_continue(term, state) do
    if function_exported?(state.module, :handle_continue, 2) do
      state.module.handle_continue(term, state.inner) |> route(state)
    else
      {:stop, {:missing_callback, :handle_continue}, state}
    end
  end

  @impl GenServer
  def handle_info(
        {:typesafe_sdk_otp_server, marker, tag, result},
        %{message_marker: marker} = state
      ) do
    state.module.handle_evaluation(result, tag, state.inner) |> route(state)
  end

  def handle_info({ref, result}, %{pending: pending} = state) when is_map_key(pending, ref) do
    Process.demonitor(ref, [:flush])
    {entry, state} = pop_pending(state, ref)
    stop_watcher(entry.cancellation_watcher)
    state.module.handle_evaluation(result, entry.tag, state.inner) |> route(state)
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{pending: pending} = state)
      when is_map_key(pending, ref) do
    {entry, state} = pop_pending(state, ref)
    stop_watcher(entry.cancellation_watcher)
    cancel(entry.cancellation)

    error = %Error{
      type: :task_exit,
      message: "OTP semantic evaluation worker exited",
      details: %{scope: :otp_server}
    }

    state.module.handle_evaluation({:error, error}, entry.tag, state.inner) |> route(state)
  end

  def handle_info({ref, _result} = message, state) when is_reference(ref) do
    case Enum.find(state.pending, fn
           {_request_ref, %{cancellation_watcher: {%Task{ref: watcher_ref}, _stop}}} ->
             watcher_ref == ref

           _ ->
             false
         end) do
      {request_ref, entry} ->
        Process.demonitor(ref, [:flush])
        entry = %{entry | cancellation_watcher: nil}
        {:noreply, %{state | pending: Map.put(state.pending, request_ref, entry)}}

      nil ->
        delegate_info(message, state)
    end
  end

  def handle_info(message, state) do
    delegate_info(message, state)
  end

  defp delegate_info(message, state) do
    if function_exported?(state.module, :handle_info, 2) do
      state.module.handle_info(message, state.inner) |> route(state)
    else
      {:noreply, state}
    end
  end

  @impl GenServer
  def terminate(reason, state) do
    cancel_pending(state.pending)

    if function_exported?(state.module, :terminate, 2) do
      state.module.terminate(reason, state.inner)
    end
  end

  @impl GenServer
  def code_change(old_vsn, state, extra) do
    if function_exported?(state.module, :code_change, 3) do
      with {:ok, inner} <- state.module.code_change(old_vsn, state.inner, extra) do
        {:ok, %{state | inner: inner}}
      end
    else
      {:ok, state}
    end
  end

  @impl GenServer
  def format_status(status) do
    Map.update!(status, :state, fn state ->
      %{
        module: state.module,
        inner: state.inner,
        in_flight: map_size(state.pending),
        max_in_flight: state.max_in_flight
      }
    end)
  end

  defp wrap(module, inner, client, task_supervisor, max_in_flight, evaluation_options) do
    %{
      module: module,
      inner: inner,
      client: client,
      task_supervisor: task_supervisor,
      max_in_flight: max_in_flight,
      evaluation_options: evaluation_options,
      message_marker: make_ref(),
      pending: %{}
    }
  end

  defp route({:evaluate, {tag, semantic_state, questions}, inner}, state),
    do: route({:evaluate, {tag, semantic_state, questions, []}, inner}, state)

  defp route({:evaluate, {tag, semantic_state, questions, opts}, inner}, state) do
    state = %{state | inner: inner}

    case Evaluation.validate_options(opts) do
      :ok ->
        if map_size(state.pending) >= state.max_in_flight do
          overloaded = %Error{
            type: :runtime_capability,
            message: "TypeSafe OTP server max_in_flight limit reached",
            details: %{scope: :otp_server, max_in_flight: state.max_in_flight}
          }

          deliver_later(state, tag, {:error, overloaded})
        else
          start_evaluation(state, tag, semantic_state, questions, opts)
        end

      {:error, error} ->
        deliver_later(state, tag, {:error, error})
    end
  end

  defp route({:reply, reply, inner}, state), do: {:reply, reply, %{state | inner: inner}}

  defp route({:reply, reply, inner, extra}, state),
    do: {:reply, reply, %{state | inner: inner}, extra}

  defp route({:noreply, inner}, state), do: {:noreply, %{state | inner: inner}}
  defp route({:noreply, inner, extra}, state), do: {:noreply, %{state | inner: inner}, extra}
  defp route({:stop, reason, inner}, state), do: {:stop, reason, %{state | inner: inner}}

  defp route({:stop, reason, reply, inner}, state),
    do: {:stop, reason, reply, %{state | inner: inner}}

  defp route(_other, _state),
    do: raise(ArgumentError, "invalid TypeSafeSDK.OTP.Server callback return")

  defp start_evaluation(state, tag, semantic_state, questions, request_opts) do
    opts = Keyword.merge(state.evaluation_options, request_opts)

    case scoped_cancellation(opts) do
      {:ok, opts, cancellation, cancellation_watcher} ->
        try do
          task =
            Task.Supervisor.async_nolink(state.task_supervisor, fn ->
              Evaluation.run(state.client, semantic_state, questions, opts)
            end)

          entry = %{
            task: task,
            tag: tag,
            cancellation: cancellation,
            cancellation_watcher: cancellation_watcher
          }

          {:noreply, %{state | pending: Map.put(state.pending, task.ref, entry)}}
        rescue
          _error ->
            supervisor_rejected(state, tag, cancellation, cancellation_watcher)
        catch
          :exit, _reason ->
            supervisor_rejected(state, tag, cancellation, cancellation_watcher)
        end

      {:error, error} ->
        deliver_later(state, tag, {:error, error})
    end
  end

  defp supervisor_rejected(state, tag, cancellation, cancellation_watcher) do
    stop_watcher(cancellation_watcher)
    cancel(cancellation)

    error = %Error{
      type: :runtime_capability,
      message: "TypeSafe OTP task supervisor rejected evaluation",
      details: %{scope: :otp_server, capability: :task_supervisor}
    }

    deliver_later(state, tag, {:error, error})
  end

  defp deliver_later(state, tag, result) do
    send(self(), {:typesafe_sdk_otp_server, state.message_marker, tag, result})
    {:noreply, state}
  end

  defp scoped_cancellation(opts) do
    token = Pristine.Cancellation.new()

    case Keyword.get(opts, :cancellation) do
      nil ->
        {:ok, Keyword.put(opts, :cancellation, token), token, nil}

      caller_token ->
        case Pristine.Cancellation.validate(caller_token) do
          {:ok, caller_token} ->
            watcher = watch_cancellation(caller_token, token)

            {:ok, Keyword.put(opts, :cancellation, token), token, watcher}

          _ ->
            cancel(token)

            {:error,
             Error.invalid_request(
               ["options", "cancellation"],
               "must be a valid Pristine.Cancellation token"
             )}
        end
    end
  end

  defp watch_cancellation(caller_token, token) do
    watcher = Pristine.Cancellation.watch(caller_token, fn -> cancel(token) end)
    if Pristine.Cancellation.cancelled?(caller_token), do: cancel(token)
    watcher
  end

  defp pop_pending(%{pending: pending} = state, ref) do
    {entry, pending} = Map.pop!(pending, ref)
    {entry, %{state | pending: pending}}
  end

  defp cancel_pending(pending) do
    Enum.each(pending, fn {_ref, entry} ->
      stop_watcher(entry.cancellation_watcher)
      cancel(entry.cancellation)
      shutdown(entry.task)
    end)
  end

  defp stop_watcher(nil), do: :ok

  defp stop_watcher(watcher) do
    Pristine.Cancellation.stop_watcher(watcher)
  rescue
    _ -> :ok
  catch
    _, _ -> :ok
  end

  defp cancel(token) do
    Pristine.Cancellation.cancel(token)
  catch
    _, _ -> :ok
  end

  defp shutdown(task) do
    Task.shutdown(task, :brutal_kill)
  catch
    :exit, _ -> :ok
  end

  defp client(opts) do
    case Keyword.get(opts, :client) do
      %Client{} = client -> {:ok, client}
      _ -> {:error, Error.configuration("TypeSafeSDK.OTP.Server requires :client")}
    end
  end

  defp task_supervisor(opts) do
    case Keyword.get(opts, :task_supervisor) do
      nil ->
        {:error, Error.configuration("TypeSafeSDK.OTP.Server requires :task_supervisor")}

      supervisor ->
        case GenServer.whereis(supervisor) do
          nil ->
            {:error, Error.configuration("TypeSafeSDK.OTP.Server :task_supervisor is not running")}

          _pid ->
            {:ok, supervisor}
        end
    end
  end

  defp max_in_flight(opts) do
    case Keyword.get(opts, :max_in_flight, 32) do
      value when is_integer(value) and value in 1..1024 -> {:ok, value}
      _ -> {:error, Error.invalid_request(["max_in_flight"], "must be in 1..1024")}
    end
  end

  defp evaluation_options(opts) do
    value = Keyword.get(opts, :evaluation_options, [])

    if is_list(value) and Keyword.keyword?(value) do
      case Evaluation.validate_options(value) do
        :ok -> {:ok, value}
        {:error, error} -> {:error, error}
      end
    else
      {:error, Error.invalid_request(["evaluation_options"], "must be a keyword list")}
    end
  end
end
