defmodule Mix.Tasks.Typesafe.Prereq do
  use Mix.Task

  alias Pristine.SDK.ProviderProfile

  @moduledoc false
  @shortdoc "Verifies the required Pristine 0.4 runtime contract"

  @impl true
  def run(_args) do
    Mix.Task.run("app.start")
    verify_status_ranges!()
    verify_cancellation_contract!()
    Mix.shell().info("Pristine 0.4 runtime prerequisite verified")
  end

  defp verify_status_ranges! do
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
      Mix.raise("Pristine prerequisite missing: provider status-range override contract")
    end
  end

  defp verify_cancellation_contract! do
    token = Pristine.Cancellation.new()

    unless Pristine.Cancellation.cancelled?(token) == false do
      Mix.raise("Pristine prerequisite missing: cancellation token contract")
    end

    client = TypeSafeSDK.new_client(api_key: "typesafe-prereq-audit-only")
    report = Pristine.RuntimeCapabilities.transport(client.pristine_client)

    for capability <- [:unary_cancellation, :cancellation_cleanup] do
      unless get_in(report, [:capabilities, capability, :status]) == :supported do
        Mix.raise("Pristine prerequisite missing: #{capability} is not verified by the default transport")
      end
    end
  end
end
