defmodule TypeSafeSDK.QuestionTest do
  use ExUnit.Case, async: true

  alias TypeSafeSDK.{Choice, Noul, Question, Score}

  test "normalizes typed questions into the Python-compatible wire shape" do
    questions = %{
      billing: %Noul{instructions: "Is this billing?"},
      tone: %Choice{instructions: "Tone?", criteria: %{"calm" => nil, "angry" => nil}},
      urgency: %Score{instructions: "Urgency?", criteria: ["low", "high"]}
    }

    assert {:ok, normalized} = Question.normalize_questions(questions)

    assert normalized == %{
             "billing" => %{"type" => "noul", "instructions" => "Is this billing?"},
             "tone" => %{
               "type" => "choice",
               "instructions" => "Tone?",
               "criteria" => %{"calm" => nil, "angry" => nil}
             },
             "urgency" => %{
               "type" => "score",
               "instructions" => "Urgency?",
               "criteria" => ["low", "high"]
             }
           }
  end

  test "preserves forward-compatible raw question fields" do
    raw = %{"type" => "future", "nested" => %{"k" => nil}, "weight" => 3}
    assert {:ok, %{"raw" => ^raw}} = Question.normalize_questions(%{"raw" => raw})
  end

  test "leaves invalid typed choice criteria shape to the API" do
    question = Choice.new(["invalid", "shape"])

    assert {:ok, normalized} = Question.normalize_questions(%{"q" => question})
    assert normalized["q"] == %{"type" => "choice", "criteria" => ["invalid", "shape"]}
  end

  test "requires at least one question" do
    assert {:error, %TypeSafeSDK.Error{type: :configuration, message: message}} =
             Question.normalize_questions(%{})

    assert message =~ "At least one question"
  end

  test "rejects score questions with an empty rubric" do
    assert {:error, %TypeSafeSDK.Error{message: message}} =
             Question.normalize_questions(%{rating: %Score{criteria: []}})

    assert message =~ "no criteria"
  end
end
