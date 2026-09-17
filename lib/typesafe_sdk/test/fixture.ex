defmodule TypeSafeSDK.Test.Fixture do
  @moduledoc false
  alias TypeSafeSDK.JSON
  alias TypeSafeSDK.Test.ContractError

  def respond({kind, value}, request) when kind in [:answers, :models, :http_error, :response],
    do: respond({kind, value, []}, request)
  def respond({:callback, fun}, request) when is_function(fun, 1), do: respond(fun.(request), request)
  def respond({:transport_error, reason}, _request), do: {:error, reason}
  def respond({:response, body, opts}, _), do: response(Keyword.get(opts, :status, 200), body, opts)
  def respond({:http_error, status, opts}, _) do
    check!(is_integer(status) and status >= 400 and status <= 999, "HTTP error status must be >= 400")
    ms = Keyword.get(opts, :retry_after_ms)
    headers = headers(opts)
    headers = if is_nil(ms), do: headers, else: Map.put(headers, "retry-after-ms", to_string(ms))
    response(status, Keyword.get(opts, :body, %{"error" => "scripted test error"}),
      Keyword.put(opts, :headers, headers))
  end
  def respond({:models, models, opts}, request) do
    endpoint!(request, "models")
    models = normalize!(models, ["models"])
    check!(is_list(models), "model fixtures must be a list")
    response(200, %{"models" => models}, opts)
  end
  def respond({:answers, specs, opts}, request) do
    endpoint!(request, "systemone")
    body = request.body |> IO.iodata_to_binary() |> Jason.decode!()
    questions = Map.fetch!(body, "questions")
    specs = keyed!(specs, ["stubs"])
    specs = Map.new(specs, fn {key, spec} -> {JSON.wire_key(key), spec} end)
    sent = MapSet.new(Map.keys(questions))
    stubbed = MapSet.new(Map.keys(specs))
    check!(sent == stubbed,
      "sent but not stubbed: #{inspect(MapSet.to_list(MapSet.difference(sent, stubbed)))}; " <>
      "stubbed but not sent: #{inspect(MapSet.to_list(MapSet.difference(stubbed, sent)))}")
    answers = Map.new(questions, fn {id, question} ->
      {id, answer!(Map.fetch!(specs, id), question, id)}
    end)
    usage = normalize!(Keyword.get(opts, :usage, %{input_tokens: 0, output_tokens: 0}), ["usage"])
    check!(is_map(usage) and Enum.all?(Map.values(usage), &(is_integer(&1) and &1 >= 0)),
      "usage values must be nonnegative integers")
    model = Keyword.get(opts, :model, body["model"])
    check!(is_binary(model), "model must be a string")
    response(200, %{"model" => model, "usage" => usage, "answers" => answers}, opts)
  end
  def respond(_, _), do: fail!("unsupported TypeSafe test fixture")

  defp answer!({:raw, answer}, _question, _id), do: normalize!(answer, ["answer"])
  defp answer!({:noul, value}, %{"type" => "noul"}, id) do
    probability!(value, "#{id}.noul")
    %{"type" => "noul", "noul" => value}
  end
  defp answer!({:choice, choice, probabilities, confidence}, question, id),
    do: answer!({:choice, choice, [probabilities: probabilities, confidence: confidence]}, question, id)
  defp answer!({:choice, choice, confidence}, question, id) when is_number(confidence),
    do: answer!({:choice, choice, [confidence: confidence]}, question, id)
  defp answer!({:choice, choice, opts}, %{"type" => "choice", "criteria" => criteria}, id)
      when is_list(opts) do
    fixture_options!(opts)
    check!(is_atom(choice) or is_binary(choice), "#{id}: choice must be an atom or string")
    choice = JSON.wire_key(choice)
    check!(Map.has_key?(criteria, choice), "#{id}: selected option is not in the actual request")
    confidence = Keyword.get(opts, :confidence, 1.0)
    probability!(confidence, "#{id}.confidence")
    probabilities = case Keyword.fetch(opts, :probabilities) do
      {:ok, exact} -> exact |> keyed!(["stubs", id, "probabilities"])
        |> Map.new(fn {key, p} -> {JSON.wire_key(key), p} end)
      :error ->
        count = map_size(criteria)
        check!(count >= 2, "#{id}: at least two options are required by synthesized fixtures")
        Map.new(criteria, fn {key, _} -> {key, if(key == choice, do: confidence, else: (1 - confidence) / (count - 1))} end)
    end
    distribution!(probabilities, Map.keys(criteria), id)
    %{"type" => "choice", "choice" => choice, "confidence" => confidence, "probabilities" => probabilities}
  end
  defp answer!({:score, score, confidence}, question, id) when is_number(confidence),
    do: answer!({:score, score, [confidence: confidence]}, question, id)
  defp answer!({:score, score, opts}, %{"type" => "score", "criteria" => criteria}, id)
      when is_list(opts) do
    fixture_options!(opts)
    top = length(criteria) - 1
    check!(top >= 1 and is_number(score) and score >= 0 and score <= top,
      "#{id}: score is outside the actual question's range")
    confidence = Keyword.get(opts, :confidence, 1.0)
    probability!(confidence, "#{id}.confidence")
    indices = Enum.to_list(0..top)
    probabilities = case Keyword.fetch(opts, :probabilities) do
      {:ok, exact} -> score_probabilities!(exact, id)
      :error ->
        low = floor(score)
        high = ceil(score)
        Map.new(indices, fn index ->
          p = cond do
            low == high and index == low -> 1.0
            index == low -> high - score
            index == high -> score - low
            true -> 0.0
          end
          {index, p}
        end)
    end
    distribution!(probabilities, indices, id)
    legend = criteria |> Enum.with_index() |> Map.new(fn {label, index} -> {Integer.to_string(index), label} end)
    %{"type" => "score", "score" => score, "confidence" => confidence,
      "legend" => legend, "probabilities" => Map.new(probabilities, fn {k, v} -> {Integer.to_string(k), v} end)}
  end
  defp answer!(_, question, id), do: fail!("#{id}: stub type does not match actual question #{inspect(question["type"])}")

  defp fixture_options!(opts) do
    case TypeSafeSDK.Question.Validation.options(opts, [:probabilities, :confidence]) do
      :ok -> :ok
      {:error, error} -> fail!(error.message)
    end
  end
  defp score_probabilities!(value, id) when is_map(value) or is_list(value) do
    Enum.reduce(value, %{}, fn
      {key, probability}, acc ->
      key = case key do
        key when is_integer(key) -> key
        key when is_binary(key) ->
          case Integer.parse(key) do
            {integer, ""} -> integer
            _ -> fail!("#{id}: score probability keys must be integers")
          end
        _ -> fail!("#{id}: score probability keys must be integers")
      end
      check!(not Map.has_key?(acc, key), "#{id}: duplicate normalized score probability key")
      Map.put(acc, key, probability)
      _, _ -> fail!("#{id}: expected score probability key/value pairs")
    end)
  end
  defp score_probabilities!(_, id), do: fail!("#{id}: expected probability map or pairs")

  defp distribution!(values, keys, id) do
    check!(MapSet.new(Map.keys(values)) == MapSet.new(keys), "#{id}: probability keys differ from the actual question")
    Enum.each(values, fn {_, p} -> probability!(p, "#{id}.probabilities") end)
    check!(abs(Enum.sum(Map.values(values)) - 1.0) <= 1.0e-9, "#{id}: probabilities must sum to 1")
  end
  defp probability!(value, field), do: check!(is_number(value) and value >= 0 and value <= 1, "#{field}: expected probability in [0, 1]")
  defp endpoint!(request, endpoint), do: check!(String.ends_with?(URI.parse(request.url).path || "", "/v1/#{endpoint}"), "fixture endpoint mismatch")
  defp normalize!(value, path) do
    case JSON.normalize(value, path) do
      {:ok, normalized} -> normalized
      {:error, error} -> fail!(error.message)
    end
  end
  defp keyed!(value, path) do
    case JSON.keyed_pairs(value, path) do
      {:ok, pairs} -> pairs
      {:error, error} -> fail!(error.message)
    end
  end
  defp response(status, body, opts) do
    headers = opts |> headers() |> Map.put_new("content-type", "application/json")
      |> Map.put_new("x-typesafe-request-id", Keyword.get(opts, :request_id, "req_typesafe_test"))
    {:ok, %Pristine.Core.Response{status: status, body: Jason.encode!(body), headers: headers}}
  end
  defp headers(opts), do: Map.new(Keyword.get(opts, :headers, %{}), fn {k, v} -> {String.downcase(to_string(k)), to_string(v)} end)
  defp check!(true, _), do: :ok
  defp check!(false, message), do: fail!(message)
  defp fail!(message), do: raise(ContractError, message: message)
end
