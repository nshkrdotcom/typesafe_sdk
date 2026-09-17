defmodule Mix.Tasks.Typesafe.Capabilities do
  use Mix.Task
  @shortdoc "Reports advertised/unverified transport bounds; optionally enforces requirements"
  @moduledoc """
  `mix typesafe.capabilities [--require unary_cancellation,cancellation_cleanup]`

  No HTTP request is made. Required capabilities must be explicitly advertised
  by the configured transport; this does not substitute for adapter contract tests.
  """
  @impl true
  def run(args) do
    Mix.Task.run("app.start")
    {opts, remaining, invalid} = OptionParser.parse(args, strict: [require: :string])

    if remaining != [] or invalid != [],
      do: Mix.raise("usage: mix typesafe.capabilities [--require names]")

    client = TypeSafeSDK.new_client(api_key: "capability-audit-only")
    report = TypeSafeSDK.RuntimeCapabilities.report(client)
    Mix.shell().info(Jason.encode!(report, pretty: true))
    names = String.split(Keyword.get(opts, :require, ""), ",", trim: true)
    registry = Map.new(TypeSafeSDK.RuntimeCapabilities.names(), &{Atom.to_string(&1), &1})

    requirements =
      Enum.map(names, fn name ->
        case Map.fetch(registry, name) do
          {:ok, capability} -> capability
          :error -> Mix.raise("unknown capability: #{name}")
        end
      end)

    case TypeSafeSDK.RuntimeCapabilities.check(client, requirements) do
      :ok -> :ok
      {:error, error} -> Mix.raise(error.message)
    end
  end
end
