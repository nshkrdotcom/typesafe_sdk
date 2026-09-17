defmodule TypeSafeSDK.SemanticResponse do
  @moduledoc false
  alias TypeSafeSDK.{ChoiceAnswer, Error, NoulAnswer, Prepared, ScoreAnswer, SystemOneResponse}

  def enrich(%SystemOneResponse{} = response, %Prepared{} = prepared, tolerance) do
    with :ok <- missing_answers(response, prepared),
         {:ok, answers} <- join(response.answers, prepared, tolerance) do
      {:ok, %{response | answers: answers}}
    else
      {:error, error} ->
        {:error, Error.attach_response(error, response.raw_http_response, response.raw)}
    end
  end

  defp missing_answers(response, prepared) do
    case Enum.find(Map.keys(prepared.keys), fn id ->
      not Map.has_key?(response.answers, id) and not Map.has_key?(response.unknown_answers, id)
    end) do
      nil -> :ok
      id -> invalid(["answers", id], "requested question has no answer entry")
    end
  end

  defp join(answers, prepared, tolerance) do
    Enum.reduce_while(answers, {:ok, %{}}, fn {id, answer}, {:ok, acc} ->
      with {:ok, definition} <- definition(prepared, id),
           :ok <- type_matches(answer, definition.type, id),
           {:ok, enriched} <- validate(answer, definition, ["answers", id], tolerance) do
        key = Map.fetch!(prepared.keys, id)
        {:cont, {:ok, Map.put(acc, key, %{enriched | id: key})}}
      else
        error -> {:halt, error}
      end
    end)
  end

  defp definition(prepared, id) do
    case Map.fetch(prepared.definitions, id) do
      {:ok, definition} -> {:ok, definition}
      :error -> invalid(["answers", id], "known answer ID was not requested")
    end
  end

  defp type_matches(%NoulAnswer{}, "noul", _), do: :ok
  defp type_matches(%ChoiceAnswer{}, "choice", _), do: :ok
  defp type_matches(%ScoreAnswer{}, "score", _), do: :ok
  defp type_matches(_, _, id), do: invalid(["answers", id, "type"], "does not match requested question type")

  defp validate(%NoulAnswer{} = answer, _, _, _), do: {:ok, answer}
  defp validate(%ChoiceAnswer{} = answer, definition, path, tolerance) do
    with :ok <- member(answer.choice, Map.keys(definition.option_keys), path ++ ["choice"]),
         :ok <- domain(answer.probabilities, Map.keys(definition.option_keys), path ++ ["probabilities"]),
         :ok <- distribution(answer.probabilities, path ++ ["probabilities"], tolerance) do
      {:ok, %{answer | choice: Map.fetch!(definition.option_keys, answer.choice),
        probabilities: Map.new(answer.probabilities, fn {wire, p} ->
          {Map.fetch!(definition.option_keys, wire), p}
        end), option_order: definition.option_order}}
    end
  end
  defp validate(%ScoreAnswer{} = answer, definition, path, tolerance) do
    indices = Enum.map(definition.levels, & &1.index)
    top = length(indices) - 1
    with :ok <- score_range(answer.score, top, path ++ ["score"]),
         :ok <- domain(answer.probabilities, indices, path ++ ["probabilities"]),
         :ok <- domain(answer.legend, indices, path ++ ["legend"]),
         :ok <- distribution(answer.probabilities, path ++ ["probabilities"], tolerance) do
      level = Enum.at(definition.levels, round(answer.score))
      levels = Enum.map(definition.levels, &{&1.label, Map.fetch!(answer.probabilities, &1.index)})
      {:ok, %{answer | level: level.index, label: level.label, description: level.description,
        levels: levels, rubric: definition.levels}}
    end
  end

  defp member(value, keys, path) do
    if value in keys, do: :ok, else: invalid(path, "selected option was not requested")
  end
  defp domain(values, expected, path) do
    if MapSet.new(Map.keys(values)) == MapSet.new(expected), do: :ok,
      else: invalid(path, "key domain differs from the question rubric")
  end
  defp distribution(values, path, tolerance) do
    sum = Enum.sum(Map.values(values))
    if abs(sum - 1.0) <= tolerance + 1.0e-12, do: :ok,
      else: invalid(path, "probabilities must sum to 1 within the configured tolerance")
  end
  defp score_range(score, top, path) do
    if score >= 0 and score <= top, do: :ok,
      else: invalid(path, "score is outside the requested level range")
  end
  defp invalid(path, reason), do: {:error, Error.invalid_response(path, reason)}
end
