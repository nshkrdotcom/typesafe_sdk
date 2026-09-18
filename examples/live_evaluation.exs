alias TypeSafeSDK.{Choice, Noul, Score}

Code.require_file("support/live.exs", __DIR__)
client = TypeSafeSDK.Examples.Live.client()
TypeSafeSDK.Examples.Live.show_configuration(client)

show = fn label, value ->
  IO.puts("\n#{label}")
  IO.inspect(value, pretty: true, limit: :infinity, printable_limit: :infinity, width: 100)
end

unwrap = fn
  {:ok, response} ->
    response

  {:error, error} ->
    IO.puts(:stderr, "TypeSafe request failed: #{Exception.message(error)}")
    System.halt(1)
end

IO.puts("Calling the live TypeSafe API: model list, then one evaluation.")

models = unwrap.(TypeSafeSDK.list_models(client))
show.("Model list — TypeSafeSDK.ListModelsResponse.models", models.models)

state = %{
  "subject" => "Charged twice",
  "body" => "I see two charges of $49. Please fix this ASAP."
}

questions = %{
  "billing" => %Noul{instructions: "Is this ticket about billing?"},
  "tone" =>
    Choice.new(
      %{"calm" => nil, "frustrated" => nil, "angry" => nil},
      instructions: "What is the customer's tone?"
    ),
  "urgency" =>
    Score.new(["can wait", "this week", "today"], instructions: "How urgent is this ticket?")
}

show.("Input state", state)
show.("Typed questions — Noul, Choice, Score", questions)

response = TypeSafeSDK.system_one!(client, state, questions)

show.("Evaluation model — TypeSafeSDK.SystemOneResponse.model", response.model)
show.("Structured answers — NoulAnswer, ChoiceAnswer, ScoreAnswer", response.answers)
show.("Token usage — TypeSafeSDK.Usage", response.usage)

IO.puts("\nIndividual answer values:")
IO.puts("Billing probability: #{response.answers["billing"].noul}")
IO.puts("Customer tone: #{response.answers["tone"].choice}")
IO.puts("Urgency score: #{response.answers["urgency"].score}")