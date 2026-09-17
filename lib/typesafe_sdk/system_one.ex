defmodule TypeSafeSDK.SystemOne do
  alias TypeSafeSDK.Generated.SystemOne, as: GeneratedSystemOne

  @moduledoc "System One parity/raw API surface."

  alias TypeSafeSDK.{Client, Question, RequestBudget, SystemOneResponse}

  @local_options [:model, :extra_body, :max_request_bytes]

  @spec run(Client.t(), term(), map(), keyword()) :: {:ok, SystemOneResponse.t()} | {:error, term()}
  def run(%Client{} = client, state, questions, opts \\ [])
      when is_map(questions) and is_list(opts) do
    with {:ok, normalized_questions} <- Question.normalize_questions(questions) do
      body = %{
        "state" => state,
        "model" => Keyword.get(opts, :model) || client.default_model,
        "questions" => normalized_questions
      }

      body = Map.merge(body, normalize_extra_body(Keyword.get(opts, :extra_body, %{})))
      max_bytes = RequestBudget.effective(client.max_request_bytes, opts)

      with :ok <- RequestBudget.validate(max_bytes, ["options", "max_request_bytes"]),
           :ok <- RequestBudget.check(body, max_bytes) do
        call_opts = Keyword.drop(opts, @local_options)

        case GeneratedSystemOne.create(client, body, call_opts) do
          {:ok, response_body} -> SystemOneResponse.decode(response_body)
          {:error, error} -> {:error, error}
        end
      end
    end
  end

  defp normalize_extra_body(nil), do: %{}

  defp normalize_extra_body(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
  end

  defp normalize_extra_body(other) do
    raise ArgumentError, "extra_body must be a map, got: #{inspect(other)}"
  end
end
