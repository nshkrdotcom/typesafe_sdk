alias TypeSafeSDK.{Choice, Noul, Score}

api_key = System.get_env("TYPESAFE_API_KEY")

if is_nil(api_key) or String.trim(api_key) == "" do
  IO.puts(:stderr, "Set TYPESAFE_API_KEY before running this live example.")
  System.halt(1)
end

client = TypeSafeSDK.new_client(api_key: api_key, base_url: "https://api.typesafe.ai")

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

response = unwrap.(TypeSafeSDK.system_one(client, state, questions, model: "jev-latest"))

show.("Evaluation model — TypeSafeSDK.SystemOneResponse.model", response.model)
show.("Structured answers — NoulAnswer, ChoiceAnswer, ScoreAnswer", response.answers)
show.("Token usage — TypeSafeSDK.Usage", response.usage)

IO.puts("\nIndividual answer values:")
IO.puts("Billing probability: #{response.answers["billing"].noul}")
IO.puts("Customer tone: #{response.answers["tone"].choice}")
IO.puts("Urgency score: #{response.answers["urgency"].score}")
