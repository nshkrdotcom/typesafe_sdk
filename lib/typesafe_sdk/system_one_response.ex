defmodule TypeSafeSDK.SystemOneResponse do
  @moduledoc """
  Typed System One response with grouped convenience accessors.

  Responses produced by the HTTP client retain request metadata separately from
  the decoded API payload. `request_id!/1` and `raw_http_response!/1` mirror the
  Python SDK's metadata access without polluting the wire fields.
  """

  require Logger

  alias TypeSafeSDK.{ChoiceAnswer, Error, NoulAnswer, ScoreAnswer, TransportResponse, Usage}

  @enforce_keys [:model, :usage, :answers]
  defstruct [:model, :usage, :answers, :request_id, :raw_http_response]

  @type answer :: NoulAnswer.t() | ChoiceAnswer.t() | ScoreAnswer.t()
  @type t :: %__MODULE__{
          model: String.t(),
          usage: Usage.t(),
          answers: %{String.t() => answer()},
          request_id: String.t() | nil,
          raw_http_response: Pristine.Response.t() | nil
        }

  @spec decode(term()) :: {:ok, t()} | {:error, Error.t()}
  def decode(%TransportResponse{} = transport) do
    case decode(transport.data) do
      {:ok, response} ->
        {:ok,
         %{
           response
           | request_id: transport.request_id,
             raw_http_response: transport.raw_http_response
         }}

      {:error, %Error{} = error} ->
        {:error, Error.attach_response(error, transport.raw_http_response, transport.data)}
    end
  end

  def decode(body) when is_map(body) do
    with {:ok, model} <- required_string(body, "model", "model"),
         {:ok, usage} <- decode_usage(value(body, "usage")),
         {:ok, answers} <- decode_answers(value(body, "answers")) do
      {:ok, %__MODULE__{model: model, usage: usage, answers: answers}}
    end
  end

  def decode(body), do: {:error, Error.response_validation("response", body)}

  @spec request_id!(t()) :: String.t()
  def request_id!(%__MODULE__{request_id: request_id}) when is_binary(request_id), do: request_id

  def request_id!(%__MODULE__{}) do
    raise Error.configuration("The response did not include a request ID")
  end

  @spec raw_http_response!(t()) :: Pristine.Response.t()
  def raw_http_response!(%__MODULE__{raw_http_response: %Pristine.Response{} = response}),
    do: response

  def raw_http_response!(%__MODULE__{}) do
    raise Error.configuration("The response was not created from a raw HTTP response")
  end

  @spec nouls(t()) :: %{String.t() => NoulAnswer.t()}
  def nouls(%__MODULE__{answers: answers}), do: select(answers, NoulAnswer)

  @spec choices(t()) :: %{String.t() => ChoiceAnswer.t()}
  def choices(%__MODULE__{answers: answers}), do: select(answers, ChoiceAnswer)

  @spec scores(t()) :: %{String.t() => ScoreAnswer.t()}
  def scores(%__MODULE__{answers: answers}), do: select(answers, ScoreAnswer)

  defp decode_usage(usage) when is_map(usage) do
    with {:ok, input} <- optional_integer(usage, "input_tokens", "usage.input_tokens"),
         {:ok, output} <- optional_integer(usage, "output_tokens", "usage.output_tokens") do
      {:ok, %Usage{input_tokens: input, output_tokens: output}}
    end
  end

  defp decode_usage(other), do: {:error, Error.response_validation("usage", other)}

  defp decode_answers(answers) when is_map(answers) do
    Enum.reduce_while(answers, {:ok, %{}}, fn {name, raw}, {:ok, acc} ->
      case decode_answer(to_string(name), raw) do
        {:ok, :unknown} -> {:cont, {:ok, acc}}
        {:ok, answer} -> {:cont, {:ok, Map.put(acc, to_string(name), answer)}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp decode_answers(other), do: {:error, Error.response_validation("answers", other)}

  defp decode_answer(name, raw) when is_map(raw) do
    case value(raw, "type") do
      "noul" ->
        decode_noul(name, raw)

      "choice" ->
        decode_choice(name, raw)

      "score" ->
        decode_score(name, raw)

      type when is_binary(type) ->
        Logger.warning(
          "Ignoring TypeSafe answer #{inspect(name)} with unrecognized type #{inspect(type)}"
        )

        {:ok, :unknown}

      _ ->
        {:error, Error.response_validation("answers.#{name}.type", raw)}
    end
  end

  defp decode_answer(name, raw),
    do: {:error, Error.response_validation("answers.#{name}.type", raw)}

  defp decode_noul(name, raw) do
    case value(raw, "noul") do
      value when is_number(value) -> {:ok, %NoulAnswer{noul: value}}
      _ -> {:error, Error.response_validation("answers.#{name}.noul", raw)}
    end
  end

  defp decode_choice(name, raw) do
    with {:ok, choice} <- required_string(raw, "choice", "answers.#{name}.choice"),
         {:ok, confidence} <- required_number(raw, "confidence", "answers.#{name}.confidence"),
         {:ok, probabilities} <-
           string_number_map(value(raw, "probabilities"), "answers.#{name}.probabilities") do
      {:ok, %ChoiceAnswer{choice: choice, confidence: confidence, probabilities: probabilities}}
    end
  end

  defp decode_score(name, raw) do
    with {:ok, score} <- required_number(raw, "score", "answers.#{name}.score"),
         {:ok, confidence} <- required_number(raw, "confidence", "answers.#{name}.confidence"),
         {:ok, legend} <- integer_key_map(value(raw, "legend"), "answers.#{name}.legend"),
         {:ok, probabilities} <-
           integer_number_map(value(raw, "probabilities"), "answers.#{name}.probabilities") do
      {:ok,
       %ScoreAnswer{
         score: score,
         confidence: confidence,
         legend: legend,
         probabilities: probabilities
       }}
    end
  end

  defp required_string(map, key, path) do
    case value(map, key) do
      value when is_binary(value) -> {:ok, value}
      _ -> {:error, Error.response_validation(path, map)}
    end
  end

  defp required_number(map, key, path) do
    case value(map, key) do
      value when is_number(value) -> {:ok, value}
      _ -> {:error, Error.response_validation(path, map)}
    end
  end

  defp optional_integer(map, key, path) do
    case value(map, key) do
      nil -> {:ok, nil}
      value when is_integer(value) -> {:ok, value}
      _ -> {:error, Error.response_validation(path, map)}
    end
  end

  defp string_number_map(map, path) when is_map(map) do
    if Enum.all?(map, fn {key, value} ->
         (is_binary(key) or is_atom(key) or is_integer(key)) and is_number(value)
       end) do
      {:ok, Map.new(map, fn {key, value} -> {to_string(key), value} end)}
    else
      {:error, Error.response_validation(path, map)}
    end
  end

  defp string_number_map(other, path), do: {:error, Error.response_validation(path, other)}

  defp integer_key_map(map, path) when is_map(map) do
    convert_integer_keys(map, path, fn value -> {:ok, value} end)
  end

  defp integer_key_map(other, path), do: {:error, Error.response_validation(path, other)}

  defp integer_number_map(map, path) when is_map(map) do
    convert_integer_keys(map, path, fn
      value when is_number(value) -> {:ok, value}
      value -> {:error, Error.response_validation(path, value)}
    end)
  end

  defp integer_number_map(other, path), do: {:error, Error.response_validation(path, other)}

  defp convert_integer_keys(map, path, value_fun) do
    Enum.reduce_while(map, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
      with {:ok, integer_key} <- integer_key(key),
           {:ok, normalized_value} <- value_fun.(value) do
        {:cont, {:ok, Map.put(acc, integer_key, normalized_value)}}
      else
        _ -> {:halt, {:error, Error.response_validation(path, map)}}
      end
    end)
  end

  defp integer_key(key) when is_integer(key), do: {:ok, key}

  defp integer_key(key) when is_binary(key) do
    case Integer.parse(key) do
      {value, ""} -> {:ok, value}
      _ -> :error
    end
  end

  defp integer_key(_key), do: :error

  defp select(answers, module),
    do: Map.filter(answers, fn {_name, answer} -> is_struct(answer, module) end)

  defp value(map, key), do: Map.get(map, key) || Map.get(map, known_atom_key(key))
  defp known_atom_key("model"), do: :model
  defp known_atom_key("usage"), do: :usage
  defp known_atom_key("answers"), do: :answers
  defp known_atom_key("type"), do: :type
  defp known_atom_key("noul"), do: :noul
  defp known_atom_key("choice"), do: :choice
  defp known_atom_key("confidence"), do: :confidence
  defp known_atom_key("probabilities"), do: :probabilities
  defp known_atom_key("score"), do: :score
  defp known_atom_key("legend"), do: :legend
  defp known_atom_key("input_tokens"), do: :input_tokens
  defp known_atom_key("output_tokens"), do: :output_tokens
  defp known_atom_key(_), do: :__typesafe_missing_key__
end
