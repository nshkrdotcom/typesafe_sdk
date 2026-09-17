defmodule TypeSafeSDK.Evaluation do
  @moduledoc false
  alias TypeSafeSDK.Generated.SystemOne

  alias TypeSafeSDK.{
    Client,
    Error,
    JSON,
    Prepared,
    RequestBudget,
    ResponseContract,
    RetryPolicy,
    SemanticResponse,
    SystemOneResponse,
    Telemetry
  }

  alias TypeSafeSDK.Question.Validation

  @options [
    :model,
    :timeout,
    :timeout_ms,
    :retry,
    :extra_body,
    :extra_headers,
    :probability_tolerance,
    :telemetry_metadata,
    :cancellation,
    :response_contract,
    :max_request_bytes
  ]
  @semantic_options [
    :model,
    :extra_body,
    :probability_tolerance,
    :telemetry_metadata,
    :response_contract,
    :max_request_bytes
  ]

  def run(%Client{} = client, state, questions, opts \\ []) do
    Telemetry.span(metadata(client, questions, opts), fn ->
      started = System.monotonic_time(:microsecond)

      result =
        with :ok <- validate_options(opts),
             {:ok, prepared} <- Prepared.new(questions) do
          run_prepared(client, state, prepared, opts)
          |> attach_prepared_fingerprint(prepared)
        end

      timed(result, started)
    end)
  end

  defp run_prepared(client, state, prepared, opts) do
    with {:ok, state} <- JSON.normalize(state, ["state"]),
         {:ok, extra} <- extra_body(Keyword.get(opts, :extra_body)),
         {:ok, response} <- execute(client, state, prepared, extra, opts) do
      case SemanticResponse.enrich(
             response,
             prepared,
             Keyword.get(opts, :probability_tolerance, 0.02)
           ) do
        {:ok, enriched} = result ->
          :ok = Telemetry.answers(enriched, prepared, Keyword.get(opts, :telemetry_metadata, %{}))
          result

        error ->
          error
      end
    end
  end

  defp timed({:ok, response}, started) do
    elapsed = (System.monotonic_time(:microsecond) - started) / 1000
    {:ok, %{response | runtime_elapsed_ms: response.elapsed_ms, elapsed_ms: elapsed}}
  end

  defp timed({:error, %Error{} = error}, started) do
    elapsed = (System.monotonic_time(:microsecond) - started) / 1000
    {:error, %{error | details: Map.put(error.details, :elapsed_ms, elapsed)}}
  end

  defp timed(result, _started), do: result

  def validate_options(opts) do
    with :ok <- Validation.options(opts, @options),
         :ok <- optional_model(Keyword.get(opts, :model)),
         :ok <- timeout(Keyword.get(opts, :timeout), "timeout", false),
         :ok <- timeout(Keyword.get(opts, :timeout_ms), "timeout_ms", false),
         :ok <- probability_tolerance(Keyword.get(opts, :probability_tolerance, 0.02)),
         :ok <- caller_metadata(Keyword.get(opts, :telemetry_metadata, %{})),
         :ok <- headers(Keyword.get(opts, :extra_headers)),
         :ok <- retry(Keyword.get(opts, :retry)),
         :ok <- cancellation(Keyword.get(opts, :cancellation)),
         :ok <- response_contract(Keyword.get(opts, :response_contract)),
         :ok <- request_budget(Keyword.get(opts, :max_request_bytes)),
         {:ok, _} <- extra_body(Keyword.get(opts, :extra_body)) do
      :ok
    end
  end

  defp execute(client, state, prepared, extra, opts) do
    body =
      Map.merge(extra, %{
        "state" => state,
        "questions" => Prepared.encoded(prepared),
        "model" => Keyword.get(opts, :model) || client.default_model
      })

    max_bytes = RequestBudget.effective(client.max_request_bytes, opts)

    with :ok <- RequestBudget.check(body, max_bytes),
         {:ok, wire} <- SystemOne.create(client, body, Keyword.drop(opts, @semantic_options)),
         {:ok, response} <- SystemOneResponse.decode(wire),
         {:ok, contract} <-
           ResponseContract.merge(client.response_contract, Keyword.get(opts, :response_contract)),
         :ok <- ResponseContract.validate(response, prepared, contract) do
      {:ok, response}
    end
  rescue
    error in Error -> {:error, error}
  end

  defp attach_prepared_fingerprint({:ok, %SystemOneResponse{} = response}, prepared) do
    {:ok, %{response | prepared_fingerprint: Prepared.fingerprint(prepared)}}
  end

  defp attach_prepared_fingerprint({:error, %Error{} = error}, prepared) do
    {:error, Error.with_prepared_fingerprint(error, Prepared.fingerprint(prepared))}
  end

  defp attach_prepared_fingerprint(other, _prepared), do: other

  defp extra_body(nil), do: {:ok, %{}}

  defp extra_body(extra) when is_map(extra) and not is_struct(extra) do
    with {:ok, extra} <- JSON.normalize(extra, ["options", "extra_body"]) do
      case Enum.find(~w(state model questions), &Map.has_key?(extra, &1)) do
        nil -> {:ok, extra}
        key -> invalid(["options", "extra_body", key], "cannot override a semantic request field")
      end
    end
  end

  defp extra_body(_), do: invalid(["options", "extra_body"], "must be a JSON object")

  defp optional_model(nil), do: :ok

  defp optional_model(model) when is_binary(model) do
    if String.valid?(model) and String.trim(model) != "",
      do: :ok,
      else: invalid(["options", "model"], "must be a nonblank UTF-8 string")
  end

  defp optional_model(_), do: invalid(["options", "model"], "must be a string")

  defp timeout(nil, _, _), do: :ok

  defp timeout(value, key, _) when is_number(value) and value > 0 and value < 1.0e12 do
    minimum = if key == "timeout", do: 0.001, else: 1

    if value >= minimum,
      do: :ok,
      else: invalid(["options", key], "must resolve to at least 1 millisecond")
  end

  defp timeout(_, key, _), do: invalid(["options", key], "must be positive and finite")

  defp probability_tolerance(value) when is_number(value) and value >= 0 and value <= 0.1, do: :ok

  defp probability_tolerance(_),
    do: invalid(["options", "probability_tolerance"], "must be in [0, 0.1]")

  defp caller_metadata(value) when is_map(value) and not is_struct(value), do: :ok
  defp caller_metadata(_), do: invalid(["options", "telemetry_metadata"], "must be a map")

  defp retry(value) when value in [nil, false], do: :ok
  defp retry(%RetryPolicy{} = policy), do: retry(Map.from_struct(policy))

  defp retry(value) when is_list(value) do
    cond do
      not Keyword.keyword?(value) ->
        invalid(["options", "retry"], "must be a keyword list")

      length(Keyword.keys(value)) != length(Enum.uniq(Keyword.keys(value))) ->
        invalid(["options", "retry"], "duplicate retry options are not allowed")

      true ->
        retry(Map.new(value))
    end
  end

  defp retry(value) when is_map(value) do
    case RetryPolicy.new(value) do
      {:ok, _} -> :ok
      {:error, _} -> invalid(["options", "retry"], "invalid retry policy")
    end
  end

  defp retry(_), do: invalid(["options", "retry"], "must be false or a retry policy")

  defp cancellation(nil), do: :ok
  defp cancellation(%Pristine.Cancellation{}), do: :ok

  defp cancellation(_),
    do: invalid(["options", "cancellation"], "must be a Pristine.Cancellation token")

  defp response_contract(value) do
    case ResponseContract.normalize(value) do
      {:ok, _} -> :ok
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  defp request_budget(value),
    do: RequestBudget.validate(value, ["options", "max_request_bytes"])

  defp headers(nil), do: :ok

  defp headers(value) do
    path = ["options", "extra_headers"]

    with {:ok, pairs} <- JSON.keyed_pairs(value, path) do
      validate_headers(pairs, path)
    end
  end

  defp validate_headers(pairs, path) do
    Enum.reduce_while(pairs, {:ok, MapSet.new()}, fn {key, value}, {:ok, seen} ->
      name = JSON.wire_key(key)
      normalized = String.downcase(name)

      cond do
        not Regex.match?(~r/\A[!#$%&'*+.^_`|~0-9A-Za-z-]+\z/, name) ->
          {:halt, invalid(path ++ [name], "invalid HTTP header name")}

        MapSet.member?(seen, normalized) ->
          {:halt, invalid(path ++ [name], "duplicate case-insensitive header name")}

        not valid_header_value?(value) ->
          {:halt, invalid(path ++ [name], "invalid HTTP header value")}

        true ->
          {:cont, {:ok, MapSet.put(seen, normalized)}}
      end
    end)
    |> case do
      {:ok, _} -> :ok
      error -> error
    end
  end

  defp valid_header_value?(value) when is_binary(value) or is_atom(value) or is_number(value) do
    text = to_string(value)
    String.valid?(text) and not Regex.match?(~r/[\x00-\x08\x0A-\x1F\x7F]/, text)
  end

  defp valid_header_value?(_), do: false

  defp safe_count(value) do
    length(value)
  rescue
    ArgumentError -> nil
  end

  defp question_count(%Prepared{} = prepared), do: Prepared.count(prepared)
  defp question_count(q) when is_map(q) and not is_struct(q), do: map_size(q)
  defp question_count(q) when is_list(q), do: safe_count(q)
  defp question_count(_), do: nil

  defp metadata(client, questions, opts) do
    opts = if is_list(opts) and Keyword.keyword?(opts), do: opts, else: []

    count = question_count(questions)

    caller = Keyword.get(opts, :telemetry_metadata, %{})
    model = Keyword.get(opts, :model) || client.default_model

    %{
      operation: :evaluate,
      requested_model: if(is_binary(model), do: model, else: nil),
      question_count: count,
      caller: if(is_map(caller) and not is_struct(caller), do: caller, else: %{})
    }
  end

  defp invalid(path, reason), do: {:error, Error.invalid_request(path, reason)}
end
