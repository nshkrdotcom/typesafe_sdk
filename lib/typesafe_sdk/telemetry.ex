defmodule TypeSafeSDK.Telemetry do
  @moduledoc """
  Privacy-oriented semantic spans above Pristine's attempt telemetry.

  Events are `[:typesafe_sdk, :evaluate, :start | :stop | :exception]` and
  `[:typesafe_sdk, :batch, :cancelled]`. Durations use native monotonic units.
  Automatic metadata never includes state, questions, bodies, headers, API keys,
  exception reasons, stacktraces, or raw errors. Explicit `telemetry_metadata`
  is nested under `:caller`; supply identifiers, not customer content.

  A brutally killed process cannot emit a terminal event. Batch timeouts are
  observable by the owning stream; physical transport cancellation remains a
  transport capability, not a promise made by these events.
  """
  alias TypeSafeSDK.{Error, SystemOneResponse}

  @doc false
  def span(metadata, fun) do
    start = System.monotonic_time()
    metadata = Map.put(metadata, :telemetry_span_context, make_ref())
    emit(:start, %{system_time: System.system_time(), monotonic_time: start}, metadata)

    try do
      result = fun.()
      {measurements, outcome} = outcome(result)

      emit(
        :stop,
        Map.put(measurements, :duration, System.monotonic_time() - start),
        Map.merge(metadata, outcome)
      )

      result
    catch
      kind, reason ->
        emit(
          :exception,
          %{duration: System.monotonic_time() - start},
          Map.merge(metadata, %{outcome: :exception, kind: kind})
        )

        :erlang.raise(kind, reason, __STACKTRACE__)
    end
  end

  @doc false
  def cancelled(index, reason) when reason in [:timeout, :task_exit] do
    :telemetry.execute([:typesafe_sdk, :batch, :cancelled], %{count: 1}, %{
      operation: :evaluate,
      batch_index: index,
      outcome: reason
    })
  end

  defp outcome({:ok, %SystemOneResponse{} = response}) do
    measurements =
      %{}
      |> maybe_put(:input_tokens, response.usage.input_tokens)
      |> maybe_put(:output_tokens, response.usage.output_tokens)

    status = if response.raw_http_response, do: response.raw_http_response.status, else: nil

    {measurements,
     %{
       outcome: :ok,
       model: response.model,
       status: status,
       request_id: response.request_id,
       retries: response.retries
     }}
  end

  defp outcome({:error, %Error{} = error}) do
    {%{},
     %{
       outcome: :error,
       error_type: error.type,
       status: error.status,
       request_id: error.request_id,
       retries: Map.get(error.details, :retries)
     }}
  end

  defp outcome(_), do: {%{}, %{outcome: :error, error_type: :unknown}}

  defp emit(event, measurements, metadata),
    do: :telemetry.execute([:typesafe_sdk, :evaluate, event], measurements, metadata)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
