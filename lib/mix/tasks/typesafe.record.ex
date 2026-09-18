defmodule Mix.Tasks.Typesafe.Record do
  use Mix.Task
  @shortdoc "Capture real, synthetic-input live fixtures and reviewable baseline diffs"
  @moduledoc """
  `mix typesafe.record [--output tmp/live] [--baseline test/fixtures/live] [--base-url URL] [--model MODEL]`

  Requires TYPESAFE_API_KEY. `--base-url` / `--model` win over the matching
  `TYPESAFE_BASE_URL` / `TYPESAFE_DEFAULT_MODEL` environment defaults. Performs
  two real operations (including an evaluation that may be billable) with retries
  disabled: list models and one mixed-question evaluation over synthetic text.
  Never overwrites approved baselines, records authorization, or commits changes.
  """
  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    {opts, remaining, invalid} =
      OptionParser.parse(args,
        strict: [output: :string, baseline: :string, base_url: :string, model: :string]
      )

    if remaining != [] or invalid != [], do: Mix.raise("invalid typesafe.record arguments")
    key = System.get_env("TYPESAFE_API_KEY")

    if is_nil(key) or String.trim(key) == "",
      do: Mix.raise("TYPESAFE_API_KEY is required for real recording")

    output = Keyword.get(opts, :output, "tmp/live")
    baseline = Keyword.get(opts, :baseline, "test/fixtures/live")

    if Path.expand(output) == Path.expand(baseline),
      do: Mix.raise("capture output must differ from the approved baseline")

    File.mkdir_p!(output)

    client_opts =
      [api_key: key, retry: false]
      |> maybe_put(:base_url, selected(opts, :base_url, "TYPESAFE_BASE_URL"))
      |> maybe_put(:model, selected(opts, :model, "TYPESAFE_DEFAULT_MODEL"))

    client = TypeSafeSDK.new_client(client_opts)
    models = unwrap!(TypeSafeSDK.list_models(client))
    write!(output, "models.json", models.raw)

    response =
      TypeSafeSDK.evaluate!(
        client,
        "Synthetic support example: the customer asks for a copy of last month's invoice. No outage is reported.",
        billing: TypeSafeSDK.noul("Is this about billing?"),
        team:
          TypeSafeSDK.choice("Primary department?",
            billing: "Invoices",
            technical: "Product failures",
            sales: "New purchases"
          ),
        urgency: TypeSafeSDK.score("Urgency?", ["Routine", "Urgent"])
      )

    write!(output, "system-one.json", response.raw)

    write!(output, "metadata.json", %{
      "recorded_at" => DateTime.to_iso8601(DateTime.utc_now()),
      "source" => "live",
      "sdk_version" => TypeSafeSDK.version(),
      "model" => response.model,
      "models_request_id" => models.request_id,
      "evaluation_request_id" => response.request_id,
      "elapsed_ms" => response.elapsed_ms,
      "retries" => response.retries
    })

    Enum.each(["models.json", "system-one.json"], &diff!(baseline, output, &1))

    Mix.shell().info(
      "Live captures and review diffs written to #{output}; approved fixtures were not changed"
    )
  end


  defp selected(opts, key, env_name) do
    case Keyword.fetch(opts, key) do
      {:ok, value} -> value
      :error -> explicit_env(env_name)
    end
  end

  defp explicit_env(name) do
    case System.get_env(name) do
      nil ->
        nil

      value ->
        case String.trim(value) do
          "" -> Mix.raise("#{name} is set but blank; unset it or provide an explicit value")
          trimmed -> trimmed
        end
    end
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp unwrap!({:ok, value}), do: value
  defp unwrap!({:error, error}), do: raise(error)

  defp write!(directory, filename, data) do
    bytes = data |> TypeSafeSDK.JSON.ordered() |> Jason.encode!(pretty: true)
    File.write!(Path.join(directory, filename), bytes <> "\n")
  end

  defp diff!(baseline, output, filename) do
    previous = Path.join(baseline, filename)
    current = Path.join(output, filename)

    diff =
      if File.exists?(previous) do
        case System.cmd("git", ["diff", "--no-index", "--", previous, current],
               stderr_to_stdout: true
             ) do
          {text, status} when status in [0, 1] -> text
          {text, _} -> Mix.raise("could not compare approved fixture: #{text}")
        end
      else
        "No approved #{filename} baseline exists. Review this first real capture before copying it into test/fixtures/live.\n"
      end

    File.write!(Path.join(output, filename <> ".diff"), diff)
  end
end