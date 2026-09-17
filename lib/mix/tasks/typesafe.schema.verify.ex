defmodule Mix.Tasks.Typesafe.Schema.Verify do
  use Mix.Task
  @shortdoc "Verify self-contained TypeSafe JSON Schemas from committed OpenAPI"
  @moduledoc "`mix typesafe.schema.verify [--output directory]`"
  @impl true
  def run(args) do
    Mix.Task.run("app.start")
    {opts, remaining, invalid} = OptionParser.parse(args, strict: [output: :string])
    if remaining != [] or invalid != [], do: Mix.raise("usage: mix typesafe.schema.verify [--output directory]")
    directory = Keyword.get(opts, :output, "priv/json_schema")
    case TypeSafeSDK.Schema.verify(directory) do
      :ok -> Mix.shell().info("TypeSafe wire schemas are current")
      {:error, files} -> Mix.raise("Stale or unexpected schemas: #{Enum.join(files, ", ")}; run mix typesafe.schema.export")
    end
  end
end
