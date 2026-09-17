defmodule TypeSafeSDK.Telemetry do
  @moduledoc """
  Privacy-oriented semantic spans above Pristine's attempt telemetry.

  Events are `[:typesafe_sdk, :evaluate, :start | :stop | :exception]`,
  `[:typesafe_sdk, :answer]`, and `[:typesafe_sdk, :batch, :cancelled]`. Durations
  use native monotonic units.
  Automatic metadata never includes state, questions, bodies, headers, API keys,
  exception reasons, stacktraces, or raw errors. Explicit `telemetry_metadata`
  is nested under `:caller`; supply identifiers, not customer content.

  A brutally killed process cannot emit a terminal event. Batch timeouts are
  observable by the owning stream; physical transport cancellation remains a
  transport capability, not a promise made by these events.
  """
  alias TypeSafeSDK.{
    ChoiceAnswer,
    Error,
    NoulAnswer,
    Prepared,
    ScoreAnswer,
    SystemOneResponse
  }

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
  def answers(%SystemOneResponse{} = response, %Prepared{} = prepared, caller \\ %{})
      when is_map(caller) do
    fingerprint = Prepared.fingerprint(prepared)

    prepared
    |> Prepared.keys()
    |> Enum.with_index()
    |> Enum.each(fn {key, index} ->
      case Map.fetch(response.answers, key) do
        {:ok, answer} ->
          {answer_type, measurements} = answer_measurements(answer)

          :telemetry.execute([:typesafe_sdk, :answer], measurements, %{
            operation: :evaluate,
            answer_type: answer_type,
            question_index: index,
            model: bounded(response.model),
            request_id: bounded(response.request_id),
            prepared_fingerprint: fingerprint,
            caller: caller
          })

        :error ->
          :ok
      end
    end)

    :ok
  end

  @doc false
  def cancelled(index, reason) when reason in [:timeout, :task_exit] do
    :telemetry.execute([:typesafe_sdk, :batch, :cancelled], %{count: 1}, %{
      operation: :evaluate,
      batch_index: index,
      outcome: reason
    })
  end

  defp answer_measurements(%NoulAnswer{noul: probability}) do
    top = max(probability, 1 - probability)
    {:noul,
     %{confidence: top, top_probability: top, distribution_margin: abs(2 * probability - 1)}}
  end

  defp answer_measurements(%ChoiceAnswer{confidence: confidence, probabilities: probabilities}) do
    ranked = probabilities |> Map.values() |> Enum.sort(:desc)
    {:choice,
     %{
       confidence: confidence,
       top_probability: first(ranked),
       distribution_margin: margin(ranked)
     }}
  end

  defp answer_measurements(%ScoreAnswer{confidence: confidence, probabilities: probabilities}) do
    ranked = probabilities |> Map.values() |> Enum.sort(:desc)
    {:score,
     %{
       confidence: confidence,
       top_probability: first(ranked),
       distribution_margin: margin(ranked)
     }}
  end

  defp first([value | _]), do: value
  defp first([]), do: 0.0
  defp margin([first, second | _]), do: first - second
  defp margin([first]), do: first
  defp margin([]), do: 0.0

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

  defp bounded(nil), do: nil
  defp bounded(value) when is_binary(value) and byte_size(value) <= 256, do: value
  defp bounded(value) when is_binary(value), do: String.slice(value, 0, 256)
  defp bounded(_value), do: nil

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
