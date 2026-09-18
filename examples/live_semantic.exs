Code.require_file("support/live.exs", __DIR__)
alias TypeSafeSDK.Examples.Live
alias TypeSafeSDK.{Answer, Question, Response}

client = Live.client()
Live.show_configuration(client)
IO.puts("Two live semantic evaluations; reuse prepared questions across structured states.")

{:ok, urgent} =
  Question.Noul.new("Does this require immediate human attention?",
    true: "Active outage or blocked business",
    false: "Routine request"
  )

team =
  Question.Choice.new!("Which support team owns this?", [
    {:billing, %{scope: "Charges, invoices and refunds"}},
    {"technical", %{scope: "Failures and integrations"}},
    {:sales, "New purchases"}
  ])

severity =
  TypeSafeSDK.score("Business impact?", [
    {"Low", %{impact: "No interruption"}},
    {"Medium", %{impact: "Partial interruption with a workaround"}},
    {"High", %{impact: "Core work is blocked"}}
  ])

:ok = Question.validate(team)
^severity = Question.validate!(severity)
{:ok, prepared} = TypeSafeSDK.prepare([{:urgent, urgent}, {"team", team}, {:severity, severity}])

states = [
  %{subject: "Duplicate invoice", body: "Please send a corrected invoice. No service issue."},
  %{subject: "API outage", body: "All production requests fail. Our team cannot work."}
]

for state <- states do
  response =
    client
    |> TypeSafeSDK.evaluate(state, prepared,
      probability_tolerance: 0.02,
      timeout_ms: 15_000,
      retry: false
    )
    |> Live.unwrap!()

  {:ok, team_answer} = Response.fetch(response, "team")
  urgent_answer = Response.fetch!(response, :urgent)
  score = Response.fetch!(response, :severity)

  Live.show("Metadata", Live.summary(response))

  Live.show("Original question and option keys", %{
    ids: Map.keys(response.answers),
    choice: team_answer.choice
  })

  Live.show("Choice", %{
    ranked: Answer.Choice.ranked(team_answer),
    margin: Answer.Choice.margin(team_answer),
    confidence: Answer.confidence(team_answer),
    gate: Answer.gate(team_answer, act: 0.9, review: 0.7)
  })

  Live.show("Noul", %{
    yes: Answer.yes?(urgent_answer, 0.85),
    certainty: Answer.Noul.confidence(urgent_answer)
  })

  Live.show("Score", %{
    ranked: Answer.Score.ranked(score),
    expected: Answer.Score.expected_level(score),
    modal: Answer.Score.max_level(score),
    normalized: Answer.Score.normalized(score),
    label: score.label,
    description: score.description,
    rubric: score.rubric,
    server_legend: score.legend
  })

  Live.show("Filtered answer IDs", %{
    nouls: Map.keys(Response.nouls(response)),
    choices: Map.keys(Response.choices(response)),
    scores: Map.keys(Response.scores(response))
  })

  Live.show("Raw fidelity", %{
    raw_answer: team_answer.raw,
    raw_response: response.raw,
    unknown_answers: response.unknown_answers,
    http_status: Response.raw_http_response!(response).status
  })
end

IO.puts("Thresholds illustrate application policy, not calibrated correctness or safety.")
