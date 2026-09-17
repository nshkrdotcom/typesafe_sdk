defmodule Mix.Tasks.Typesafe.Prereq do
  use Mix.Task

  alias Pristine.SDK.ProviderProfile, as: ProviderProfile

  @moduledoc false
  @shortdoc "Verifies the required Pristine 0.3 provider-profile contract"

  @impl true
  def run(_args) do
    Mix.Task.run("app.start")

    profile =
      ProviderProfile.new!(
        provider: :typesafe_prereq_probe,
        retryable_groups: [],
        status_retry_ranges: [
          %{
            range: 500..599,
            retry?: true,
            telemetry_classification: :upstream_failure,
            breaker_outcome: :failure
          }
        ]
      )

    override = ProviderProfile.status_retry_override(profile, 550)

    unless is_map(override) and Map.get(override, :retry?) == true do
      Mix.raise("Pristine prerequisite missing: implement PREREQUISITE_PRISTINE_0.3.0.md first")
    end

    Mix.shell().info("Pristine 0.3 status-range prerequisite verified")
  end
end
