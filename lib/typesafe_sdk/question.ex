defmodule TypeSafeSDK.Question do
  @moduledoc "Question validation and legacy wire normalization. Strict evaluation uses `TypeSafeSDK.Prepared`."

  alias TypeSafeSDK.{Choice, Error, Noul, Score}
  alias TypeSafeSDK.Question.Validation

  @type t :: Noul.t() | Choice.t() | Score.t() | map()

  @doc "Validates one question with strict semantic rules, without sending HTTP."
  @spec validate(term()) :: :ok | {:error, Error.t()}
  def validate(question) do
    case Validation.compile(question, []) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc "Validates and returns the question, or raises a path-aware SDK error."
  @spec validate!(term()) :: term()
  def validate!(question) do
    case validate(question) do
      :ok -> question
      {:error, error} -> raise error
    end
  end

  @spec normalize_questions(map()) :: {:ok, map()} | {:error, Error.t()}
  def normalize_questions(questions) when is_map(questions) and map_size(questions) > 0 do
    Enum.reduce_while(questions, {:ok, %{}}, fn {name, question}, {:ok, acc} ->
      case normalize_question(name, question) do
        {:ok, normalized} -> {:cont, {:ok, Map.put(acc, to_string(name), normalized)}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  def normalize_questions(_questions) do
    {:error, Error.configuration("At least one question is required")}
  end

  defp normalize_question(_name, %Noul{} = question) do
    {:ok,
     %{"type" => "noul"}
     |> maybe_put("instructions", question.instructions)
     |> maybe_put("criteria", question.criteria)}
  end

  defp normalize_question(_name, %Choice{} = question) do
    {:ok,
     %{"type" => "choice", "criteria" => question.criteria}
     |> maybe_put("instructions", question.instructions)}
  end

  defp normalize_question(name, %Score{} = question) do
    if is_list(question.criteria) and question.criteria != [] do
      {:ok,
       %{"type" => "score", "criteria" => question.criteria}
       |> maybe_put("instructions", question.instructions)}
    else
      invalid(
        name,
        "Score question #{inspect(to_string(name))} has no criteria; at least one score is required"
      )
    end
  end

  defp normalize_question(name, question) when is_map(question) do
    question = stringify_top_level_keys(question)
    type = question["type"]
    criteria_present? = Map.has_key?(question, "criteria")
    criteria = question["criteria"]

    cond do
      not (is_binary(type) and type != "") ->
        invalid(name, "must be a question struct or a map with a nonempty string type")

      type in ["choice", "score"] and not criteria_present? ->
        invalid(name, "requires criteria")

      type == "score" and (not is_list(criteria) or criteria == []) ->
        invalid(
          name,
          "Score question #{inspect(to_string(name))} has no criteria; at least one score is required"
        )

      true ->
        {:ok, question}
    end
  end

  defp normalize_question(name, _question) do
    invalid(name, "must be a question struct or a map with a nonempty string type")
  end

  defp invalid(name, detail) do
    {:error, Error.configuration("Question #{inspect(to_string(name))} #{detail}")}
  end

  defp stringify_top_level_keys(map),
    do: Map.new(map, fn {key, value} -> {to_string(key), value} end)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
