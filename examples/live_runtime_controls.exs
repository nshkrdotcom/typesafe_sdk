Code.require_file("support/live.exs", __DIR__)

alias TypeSafeSDK.Examples.Live
alias TypeSafeSDK.{Error, Response, RuntimeCapabilities}

client = Live.client(timeout_ms: 13_000)
Live.show_configuration(client)

# A real call with a per-call timeout and explicit retry disable. The request
# succeeding cannot prove which timeout would have won on a slower response;
# deterministic precedence is asserted in the test suite.
models = TypeSafeSDK.list_models(client, timeout_ms: 9_000, retry: false) |> Live.unwrap!()

Live.show("Timeout precedence live call", %{
  client_timeout_ms: client.timeout_ms,
  per_call_timeout_ms: 9_000,
  model_count: length(models.models),
  metadata: Response.metadata(models)
})

prepared =
  TypeSafeSDK.prepare!(
    billing: TypeSafeSDK.noul("Is this primarily about billing?"),
    route:
      TypeSafeSDK.choice("Which route fits best?", [
        {:billing, "Charges and invoices"},
        {:technical, "Failures and integrations"}
      ])
  )

response =
  TypeSafeSDK.evaluate!(
    client,
    "A duplicate invoice charge appeared after a failed checkout.",
    prepared,
    timeout: 10,
    retry: false,
    extra_headers: %{
      "authorization" => "Bearer this-value-must-never-win",
      "x-example-purpose" => "typesafe-live-runtime-controls"
    },
    extra_body: %{example_context: %{source: "live-runtime-controls"}}
  )

Live.show("Protected-header live call", %{
  values: Response.values(response),
  metadata: Response.metadata(response),
  note: "The SDK strips protected header overrides before Pristine; the test seam asserts exact wire headers."
})

case TypeSafeSDK.evaluate(client, "state", prepared,
       retry: false,
       extra_body: %{model: "must-not-override-semantic-model"}
     ) do
  {:error, %Error{type: :invalid_request} = error} ->
    Live.show("Expected strict semantic protected-field rejection (local; no request)", Error.metadata(error))

  other ->
    raise "Expected semantic extra_body protection, got: #{inspect(other)}"
end

legacy_questions = %{
  "billing" => %TypeSafeSDK.Noul{instructions: "Is the supplied state about billing?"}
}

legacy =
  TypeSafeSDK.system_one!(
    client,
    "This original legacy state is technical.",
    legacy_questions,
    timeout_ms: 10_000,
    retry: false,
    extra_body: %{
      state: "This replacement legacy state is a duplicate invoice charge.",
      example_context: "legacy-last-write-wins"
    }
  )

Live.show("Legacy system_one extra_body merge path", %{
  answer_keys: Map.keys(legacy.answers),
  metadata: Response.metadata(legacy),
  note: "Legacy system_one retains last-write-wins extra_body; semantic evaluate protects state/model/questions."
})

capabilities = RuntimeCapabilities.report(client)
Live.show("Pristine transport capability advertisement", capabilities)

Live.show(
  "Fail-closed capability check for deliberately unadvertised bounds",
  RuntimeCapabilities.check(client, [:bounded_queue, :max_response_bytes])
)

case RuntimeCapabilities.check(client, [:unary_cancellation, :cancellation_cleanup]) do
  :ok ->
    token = Pristine.Cancellation.new()

    task =
      Task.async(fn ->
        TypeSafeSDK.evaluate(
          client,
          "A real request racing a caller cancellation.",
          [continue: TypeSafeSDK.noul("Should processing continue?")],
          cancellation: token,
          timeout_ms: 12_000,
          retry: false
        )
      end)

    :ok = Pristine.Cancellation.cancel(token)

    outcome = Task.yield(task, 15_000) || Task.shutdown(task, :brutal_kill)

    case outcome do
      {:ok, {:ok, completed}} ->
        Live.show("Unary cancellation race: request legitimately completed first", Response.metadata(completed))

      {:ok, {:error, %Error{type: :cancelled} = error}} ->
        Live.show("Unary cancellation race: local cancellation won", Error.metadata(error))

      {:ok, {:error, %Error{} = error}} ->
        raise error

      other ->
        raise "Unary cancellation task did not finish cleanly: #{inspect(other)}"
    end

    batch_token = Pristine.Cancellation.new()

    batch_task =
      Task.async(fn ->
        TypeSafeSDK.evaluate_many(
          client,
          [
            "Production checkout is unavailable.",
            "Please resend last month's invoice.",
            "The login integration is failing.",
            "We need an enterprise quote."
          ],
          [urgent: TypeSafeSDK.noul("Does this need prompt attention?")],
          cancellation: batch_token,
          max_concurrency: 2,
          max_pending: 2,
          ordered: false,
          on_error: :collect,
          task_timeout_ms: 15_000,
          attempt_timeout_ms: 12_000,
          retry: false
        )
      end)

    :ok = Pristine.Cancellation.cancel(batch_token)
    batch_outcome = Task.yield(batch_task, 20_000) || Task.shutdown(batch_task, :brutal_kill)

    case batch_outcome do
      {:ok, results} when is_list(results) ->
        summary =
          Enum.map(results, fn
            {:ok, response} ->
              {:ok, response.batch_index, Response.metadata(response)}

            {:error, %Error{type: :cancelled} = error} ->
              {:error, error.details[:batch_index], Error.metadata(error)}

            {:error, %Error{} = error} ->
              Live.show("Unexpected batch request failure", Error.metadata(error))
              raise error
          end)

        Live.show("Cancellation-aware bounded batch race", %{
          returned_results: length(results),
          input_count: 4,
          outcomes: summary,
          note: "Once cancellation is observed, no new items are scheduled; already-started work is outcome-ambiguous remotely."
        })

      other ->
        raise "Batch cancellation task did not finish cleanly: #{inspect(other)}"
    end

  {:error, %Error{} = error} ->
    Live.show(
      "Cancellation example skipped because this configured transport fails closed",
      Error.metadata(error)
    )
end

if System.get_env("TYPESAFE_EXAMPLE_RETRY") == "1" do
  retry_client =
    Live.client(
      timeout_ms: 13_000,
      retry: [max_retries: 1, backoff_initial: 0.1, backoff_max: 0.2]
    )

  retry_result = TypeSafeSDK.list_models(retry_client) |> Live.unwrap!()

  Live.show("Opt-in bounded retry configuration", %{
    model_count: length(retry_result.models),
    metadata: Response.metadata(retry_result),
    note: "A successful call does not prove that a retry happened. No retryable failure is forced."
  })
else
  IO.puts("\nRetries stayed disabled. Set TYPESAFE_EXAMPLE_RETRY=1 to make one bounded live call with max_retries: 1.")
end

IO.puts("""
Ordinary cancellation tokens in this script are caller-owned and are explicitly cancelled by the
caller. TypeSafeSDK.OTP.Server is different: it creates a private token per worker and only mirrors
a caller token into it. Local cancellation/worker cleanup never proves remote non-execution or rollback.
""")
