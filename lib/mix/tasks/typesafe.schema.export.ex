defmodule Mix.Tasks.Typesafe.Schema.Export do
  use Mix.Task
  @shortdoc "Export self-contained TypeSafe JSON Schemas from committed OpenAPI"
  @moduledoc "`mix typesafe.schema.export [--output directory]`"
  @impl true
  def run(args) do
    Mix.Task.run("app.start")
    {opts, remaining, invalid} = OptionParser.parse(args, strict: [output: :string])
    if remaining != [] or invalid != [], do: Mix.raise("usage: mix typesafe.schema.export [--output directory]")
    directory = Keyword.get(opts, :output, "priv/json_schema")
    :ok = TypeSafeSDK.Schema.export(directory)
    Mix.shell().info("Exported TypeSafe wire schemas to #{directory}")
  end
end
