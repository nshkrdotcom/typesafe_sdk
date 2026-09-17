if bootstrap = System.get_env("MIX_WORKSPACE_OPS_BOOTSTRAP"), do: Code.require_file(bootstrap)

defmodule TypeSafeSDK.MixProject do
  use Mix.Project

  @version "0.1.1"
  @source_url "https://github.com/nshkrdotcom/typesafe_sdk"

  def project do
    [
      app: :typesafe_sdk,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      description: description(),
      package: package(),
      name: "TypeSafeSDK",
      source_url: @source_url,
      homepage_url: @source_url,
      docs: docs(),
      aliases: aliases(),
      dialyzer: [plt_add_apps: [:ex_unit, :mix, :pristine, :pristine_codegen]]
    ]
  end

  def application do
    [extra_applications: [:logger, :crypto]]
  end

  defp elixirc_paths(env) when env in [:dev, :test], do: ["lib", "codegen"]
  defp elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      workspace_dep({:pristine, "~> 0.3.0"}),
      {:jason, "~> 1.4.5"},
      workspace_tooling_deps(),
      {:ex_doc, "~> 0.40.4", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4.8", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7.19", only: [:dev, :test], runtime: false}
    ]
    |> List.flatten()
  end

  defp workspace_tooling_deps do
    if Mix.env() in [:dev, :test] and File.dir?(Path.join(__DIR__, "codegen")) do
      [
        workspace_dep({:pristine_codegen, "~> 0.1.0", only: [:dev, :test], runtime: false}),
        workspace_dep({:pristine_provider_testkit, "~> 0.1.0", only: :test, runtime: false})
      ]
    else
      []
    end
  end

  defp workspace_dep(committed) do
    if Code.ensure_loaded?(MixWorkspaceOpsBootstrap) and
         function_exported?(MixWorkspaceOpsBootstrap, :dep, 2) do
      apply(MixWorkspaceOpsBootstrap, :dep, [committed, __DIR__])
    else
      committed
    end
  end

  defp description do
    "Elixir SDK for the TypeSafe AI API, built on the Pristine REST SDK substrate."
  end

  defp package do
    [
      name: "typesafe_sdk",
      description: description(),
      files: ~w(lib priv/upstream guides examples README.md CHANGELOG.md LICENSE mix.exs assets),
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      maintainers: ["nshkrdotcom"]
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      canonical: "https://hexdocs.pm/typesafe_sdk",
      logo: "assets/typesafe_sdk.svg",
      assets: %{"assets" => "assets"},
      extras: [
        {"README.md", title: "Overview"},
        {"guides/index.md", title: "Guide Index", filename: "guide-index"},
        "guides/getting-started.md",
        {"examples/README.md", title: "Live API Example", filename: "live-example"},
        "guides/client-configuration.md",
        "guides/system-one-and-questions.md",
        "guides/models.md",
        "guides/errors-and-retries.md",
        "guides/generation-and-verification.md",
        "guides/upstream-provenance.md",
        "CHANGELOG.md",
        {"LICENSE", title: "License", filename: "license"}
      ],
      groups_for_extras: [
        "Start Here": ["README.md", "guides/index.md", "guides/getting-started.md"],
        Usage: [
          "guides/client-configuration.md",
          "guides/system-one-and-questions.md",
          "guides/models.md",
          "guides/errors-and-retries.md"
        ],
        Examples: ["examples/README.md"],
        Maintainers: ["guides/generation-and-verification.md", "guides/upstream-provenance.md"],
        Project: ["CHANGELOG.md", "LICENSE"]
      ],
      groups_for_modules: [
        "Client and Operations": [
          TypeSafeSDK,
          TypeSafeSDK.Client,
          TypeSafeSDK.SystemOne,
          TypeSafeSDK.Models
        ],
        Questions: [
          TypeSafeSDK.Noul,
          TypeSafeSDK.NoulCriteria,
          TypeSafeSDK.Choice,
          TypeSafeSDK.Score,
          TypeSafeSDK.Question
        ],
        Responses: [
          TypeSafeSDK.SystemOneResponse,
          TypeSafeSDK.ListModelsResponse,
          TypeSafeSDK.ModelMetadata,
          TypeSafeSDK.NoulAnswer,
          TypeSafeSDK.ChoiceAnswer,
          TypeSafeSDK.ScoreAnswer,
          TypeSafeSDK.Usage
        ],
        "Errors and Configuration": [
          TypeSafeSDK.Error,
          TypeSafeSDK.RetryPolicy,
          TypeSafeSDK.Constants
        ],
        "Generated API": ~r/^TypeSafeSDK\.Generated\./,
        "Runtime Integration": ~r/^TypeSafeSDK\.(ProviderProfile|ResultClassifier|Transport)/,
        "Maintenance Tasks": ~r/^Mix\.Tasks\.Typesafe\./
      ]
    ]
  end

  defp aliases do
    [
      ci: [
        "typesafe.prereq",
        "format --check-formatted",
        "compile --warnings-as-errors",
        "test",
        "credo --strict",
        "dialyzer",
        "docs --warnings-as-errors",
        "typesafe.verify"
      ]
    ]
  end
end
