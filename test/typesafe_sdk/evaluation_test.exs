defmodule TypeSafeSDK.EvaluationTest do
  use ExUnit.Case, async: true
  alias TypeSafeSDK.{Error, Test}

  setup do
    client = Test.client()
    on_exit(fn -> Test.close(client) end)
    %{client: client}
  end

  test "real serialization and decoding retain IDs, distributions and metadata", %{client: client} do
    client =
      Test.stub(
        client,
        [
          team:
            {:choice, :billing, probabilities: %{billing: 0.52, support: 0.48}, confidence: 0.23},
          level: {:score, 0.7, probabilities: %{0 => 0.3, 1 => 0.7}, confidence: 0.8}
        ],
        model: "jev-pinned",
        usage: %{input_tokens: 14, output_tokens: 7},
        request_id: "req-fixture"
      )

    prepared =
      TypeSafeSDK.prepare!(
        team: TypeSafeSDK.choice("Team?", support: "Help", billing: "Money"),
        level: TypeSafeSDK.score("Severity?", ["Low", "High"])
      )

    assert {:ok, response} = TypeSafeSDK.evaluate(client, %{document: ["synthetic"]}, prepared)
    assert response.answers.team.choice == :billing
    assert response.answers.team.confidence == 0.23
    assert response.model == "jev-pinned"
    assert response.request_id == "req-fixture"
    assert response.usage.input_tokens == 14
    [request] = Test.requests(client)
    body = Jason.decode!(request.body)
    assert body["state"] == %{"document" => ["synthetic"]}
    assert body["questions"] == Jason.decode!(prepared.json)
    assert request.body =~ prepared.json
    assert Test.verify!(client) == :ok
  end

  test "ordered Choice bytes survive Pristine with more than 32 options", %{client: client} do
    pairs = Enum.map(40..1//-1, &{"option_#{&1}", nil})
    client = Test.stub(client, q: {:choice, "option_40", 0.9})

    assert {:ok, response} =
             TypeSafeSDK.evaluate(client, "synthetic", q: TypeSafeSDK.choice("Pick", pairs))

    assert response.answers.q.choice == "option_40"
    [request] = Test.requests(client)
    {first, _} = :binary.match(request.body, "option_40")
    {last, _} = :binary.match(request.body, "option_1\"")
    assert first < last
  end

  test "legacy system_one still has string keys and legacy constructor return values", %{
    client: client
  } do
    client = Test.stub(client, q: {:noul, 0.9})
    question = TypeSafeSDK.Noul.new(instructions: "Question?")
    assert %TypeSafeSDK.Noul{} = question
    response = TypeSafeSDK.system_one!(client, "synthetic", %{q: question})
    assert response.answers["q"].noul == 0.9
    refute Map.has_key?(response.answers, :q)
  end

  test "invalid requests and semantic override attempts never reach transport", %{client: client} do
    question = [q: TypeSafeSDK.noul("Question?")]
    assert {:error, %Error{path: ["state"]}} = TypeSafeSDK.evaluate(client, self(), question)

    assert {:error, %Error{path: ["options", "extra_body", "questions"]}} =
             TypeSafeSDK.evaluate(client, "x", question, extra_body: %{questions: %{}})

    for opts <- [
          [probability_tolerance: 1],
          [telemetry_metadata: "bad"],
          [timeout: 0],
          [model: ""],
          [retry: [:bad]],
          [unknown: true],
          [model: "a", model: "b"]
        ] do
      assert {:error, %Error{type: :invalid_request}} =
               TypeSafeSDK.evaluate(client, "x", question, opts)
    end

    assert Test.requests(client) == []
  end

  test "local extras and per-call timeout reach the normal runtime", %{client: client} do
    client = Test.stub(client, q: {:noul, 0.9})
    question = TypeSafeSDK.Question.Noul.new!("Q?", extra: %{experimental: true})

    assert {:ok, _} =
             TypeSafeSDK.evaluate(client, "x", [q: question],
               extra_body: %{future: 4},
               timeout_ms: 1234,
               model: "jev-override"
             )

    [request] = Test.requests(client)
    body = Jason.decode!(request.body)
    assert body["future"] == 4
    assert body["model"] == "jev-override"
    assert body["questions"]["q"]["experimental"] == true
    assert request.metadata.timeout == 1234
  end

  test "response-relative errors retain actual HTTP metadata", %{client: client} do
    client =
      Test.stub_response(client, %{"model" => "jev", "usage" => %{}, "answers" => %{}},
        request_id: "req-bad"
      )

    assert {:error, %Error{type: :response_validation, status: 200, request_id: "req-bad"} = error} =
             TypeSafeSDK.evaluate(client, "x", q: TypeSafeSDK.noul("Q?"))

    assert error.raw_http_response.status == 200
    assert error.path == ["answers", "q"]
  end

  test "bang evaluation raises the normalized error", %{client: client} do
    client = Test.stub_http_error(client, 401)
    assert_raise Error, fn -> TypeSafeSDK.evaluate!(client, "x", q: TypeSafeSDK.noul("Q?")) end
  end

  test "finite sequences exercise real provider retries and retry count headers" do
    client =
      Test.client(retry: [max_retries: 2, backoff_initial: 0, backoff_jitter: 0])
      |> Test.stub_sequence([{:http_error, 529}, {:http_error, 599}, {:answers, [q: {:noul, 0.8}]}])

    assert {:ok, response} = TypeSafeSDK.evaluate(client, "x", q: TypeSafeSDK.noul("Q?"))
    assert response.retries == 2
    assert Test.stats(client).total == 3

    retry_headers =
      Enum.map(Test.requests(client), fn request ->
        Map.new(request.headers, fn {k, v} -> {String.downcase(k), v} end)["x-typesafe-retry-count"]
      end)

    assert retry_headers == [nil, "1", "2"]
    assert Test.verify!(client) == :ok
    Test.close(client)
  end

  test "retry advice is public and respects classification and configured flags", %{client: client} do
    client = Test.stub_http_error(client, 429, retry_after_ms: 1200)
    assert {:error, error} = TypeSafeSDK.evaluate(client, "x", q: TypeSafeSDK.noul("Q?"))
    assert Error.retry_after(error) == 1200
    assert Error.retryable?(error)
    refute Error.retryable?(error, false)
    assert Error.retryable?(%Error{status: 550})
    refute Error.retryable?(%Error{status: 200, type: :response_validation})
    policy = TypeSafeSDK.RetryPolicy.new!(api_timeout_error: false)
    refute Error.retryable?(%Error{type: :timeout}, policy)
    refute Error.retryable?(%Error{type: :timeout, details: %{scope: :batch}})
  end

  test "transport errors use the real error mapper", %{client: client} do
    client = Test.stub_transport_error(client, :timeout)

    assert {:error, %Error{type: :timeout}} =
             TypeSafeSDK.evaluate(client, "x", q: TypeSafeSDK.noul("Q?"))

    client = Test.stub_transport_error(client, :econnrefused)

    assert {:error, %Error{type: :connection}} =
             TypeSafeSDK.evaluate(client, "x", q: TypeSafeSDK.noul("Q?"))
  end

  test "test fixtures validate actual question contracts and verification cannot hide failures", %{
    client: client
  } do
    client = Test.stub(client, old_id: {:noul, 0.8})
    # Runtime versions may surface a transport exception or normalize it; verification
    # records the fixture failure at the seam in either case.
    try do
      TypeSafeSDK.evaluate(client, "x", new_id: TypeSafeSDK.noul("Q?"))
    rescue
      Test.ContractError -> :ok
    end

    assert_raise Test.ContractError, ~r/sent but not stubbed/, fn -> Test.verify!(client) end
  end

  test "model stubs and bounded history retain real decoded metadata" do
    client =
      Test.client(history_limit: 2)
      |> Test.stub_models([
        %{name: "jev-test", description: "Synthetic fixture", release_date: "2026-09-16"}
      ])

    for _ <- 1..3, do: assert({:ok, _} = TypeSafeSDK.list_models(client))
    assert %{total: 3, dropped: 1, requests: requests} = Test.stats(client)
    assert length(requests) == 2
    {:ok, models} = TypeSafeSDK.list_models(client)
    assert models.raw["models"] |> hd() |> Map.fetch!("name") == "jev-test"
    Test.close(client)
  end

  test "pending and exhausted sequences are observable", %{client: client} do
    client = Test.stub_sequence(client, [{:answers, [q: {:noul, 1.0}]}])
    assert_raise Test.ContractError, ~r/not consumed/, fn -> Test.verify!(client) end
    assert {:ok, _} = TypeSafeSDK.evaluate(client, "x", q: TypeSafeSDK.noul("Q?"))

    try do
      TypeSafeSDK.evaluate(client, "x", q: TypeSafeSDK.noul("Q?"))
    rescue
      Test.ContractError -> :ok
    end

    assert_raise Test.ContractError, ~r/exhausted/, fn -> Test.verify!(client) end
  end

  test "header validation rejects control characters, collisions and non-stringifiable data", %{
    client: client
  } do
    for headers <- [
          [{"X-Trace", "ok"}, {"x-trace", "different"}],
          %{"X-Trace" => "ok\r\nInjected: value"},
          %{"not a header" => "value"},
          %{"X-Trace" => %{not: "a header value"}}
        ] do
      assert {:error, %Error{type: :invalid_request}} =
               TypeSafeSDK.evaluate(client, "x", [q: TypeSafeSDK.noul("Q?")],
                 extra_headers: headers
               )
    end

    assert Test.requests(client) == []
  end

  test "fixture backoff and breaker state are isolated and cleaned with the scenario" do
    limited = Test.client() |> Test.stub_http_error(429, retry_after_ms: 60_000)
    healthy = Test.client() |> Test.stub(q: {:noul, 0.9})
    registry = limited.context.rate_limit_opts[:registry]
    breaker = limited.context.circuit_breaker_opts[:registry]
    refute registry == healthy.context.rate_limit_opts[:registry]
    refute breaker == healthy.context.circuit_breaker_opts[:registry]

    assert {:error, %Error{status: 429}} =
             TypeSafeSDK.evaluate(limited, "limited", q: TypeSafeSDK.noul("Q?"))

    task = Task.async(fn -> TypeSafeSDK.evaluate(healthy, "healthy", q: TypeSafeSDK.noul("Q?")) end)
    assert {:ok, _} = Task.await(task, 1000)
    assert :ok = Test.close(limited)
    assert :ets.info(registry) == :undefined
    assert :ets.info(breaker) == :undefined
  end
end
