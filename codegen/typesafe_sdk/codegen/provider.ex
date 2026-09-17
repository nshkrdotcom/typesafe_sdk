defmodule TypeSafeSDK.Codegen.Provider do
  alias TypeSafeSDK.Codegen.Source.OpenAPI, as: OpenAPI

  @moduledoc false
  @behaviour PristineCodegen.Provider

  alias TypeSafeSDK.Constants

  @impl true
  def definition(_opts) do
    %{
      provider: %{
        id: :typesafe,
        base_module: TypeSafeSDK,
        client_module: TypeSafeSDK.Client,
        package_app: :typesafe_sdk,
        package_name: "typesafe_sdk",
        source_strategy: :openapi_snapshot
      },
      runtime_defaults: %{
        base_url: Constants.default_base_url(),
        default_headers: %{"Accept" => "application/json"},
        user_agent_prefix: "typesafe-sdk",
        timeout_ms: Constants.default_timeout_ms(),
        retry_defaults: %{max_retries: 2, backoff_initial: 0.5, backoff_max: 5.0},
        serializer: Pristine.Adapters.Serializer.JSON,
        typed_responses_default: false
      },
      operations: [],
      schemas: [],
      auth_policies: [],
      pagination_policies: [],
      docs_inventory: %{
        guides: [%{path: "guides/system-one-and-questions.md"}, %{path: "guides/models.md"}],
        examples: [],
        operations: %{}
      },
      artifact_plan: %{
        generated_code_dir: "lib/typesafe_sdk/generated",
        artifacts: [
          %{id: :provider_ir, path: "priv/generated/provider_ir.json"},
          %{id: :generation_manifest, path: "priv/generated/generation_manifest.json"},
          %{id: :docs_inventory, path: "priv/generated/docs_inventory.json"},
          %{id: :source_inventory, path: "priv/generated/source_inventory.json"},
          %{id: :operation_auth_policies, path: "priv/generated/operation_auth_policies.json"}
        ],
        forbidden_paths: []
      },
      fingerprints: %{sources: [], generation: %{generator: "pristine_codegen"}}
    }
  end

  @impl true
  def paths(opts) do
    project_root = Keyword.get(opts, :project_root, project_root())

    %{
      project_root: project_root,
      generated_code_dir:
        Keyword.get(
          opts,
          :generated_code_dir,
          Path.join(project_root, "lib/typesafe_sdk/generated")
        ),
      generated_artifact_dir:
        Keyword.get(
          opts,
          :generated_artifact_dir,
          Path.join(project_root, "priv/generated")
        )
    }
  end

  @impl true
  def source_plugins, do: [TypeSafeSDK.Codegen.Source.OpenAPI]
  @impl true
  def auth_plugins, do: []
  @impl true
  def pagination_plugins, do: []
  @impl true
  def docs_plugins, do: []

  @impl true
  def refresh(opts) do
    OpenAPI.refresh!(opts)
  end

  def project_root, do: Path.expand("../../..", __DIR__)
end
