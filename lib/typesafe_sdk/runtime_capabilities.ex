defmodule TypeSafeSDK.RuntimeCapabilities do
  @moduledoc """
  Fail-closed TypeSafe-facing view of Pristine transport capabilities.

  Discovery delegates exclusively to `Pristine.RuntimeCapabilities.transport/1`.
  TypeSafe does not infer support from adapter names or optional callbacks and
  never exposes transport context/options through this report.
  """

  alias TypeSafeSDK.{Client, Error}

  @capabilities [
    :unary_cancellation,
    :cancellation_cleanup,
    :bounded_outstanding_requests,
    :bounded_queue,
    :max_response_bytes,
    :deterministic_overload
  ]

  @spec names() :: [atom()]
  def names, do: @capabilities

  @spec report(Client.t() | Pristine.Client.t() | Pristine.Core.Context.t()) :: map()
  def report(source) do
    pristine = Pristine.RuntimeCapabilities.transport(pristine_source(source))

    runtime =
      Map.new(@capabilities, fn capability ->
        {capability, Map.get(pristine.capabilities, capability, %{status: :unverified})}
      end)

    %{
      transport: inspect(pristine.adapter),
      runtime: runtime,
      sdk: %{
        batch_concurrency: :bounded_per_enumeration,
        batch_queue: :lazy_enumeration,
        ordered_prefetch: :bounded_windows,
        batch_cancellation: :shared_pristine_token
      },
      assurance: :pristine_transport_contract
    }
  end

  @spec check(Client.t() | Pristine.Client.t() | Pristine.Core.Context.t(), [atom()]) ::
          :ok | {:error, Error.t()}
  def check(_client, []), do: :ok

  def check(client, requirements) when is_list(requirements) do
    runtime = report(client).runtime

    missing =
      Enum.reject(requirements, fn name ->
        is_atom(name) and get_in(runtime, [name, :status]) == :supported
      end)

    if missing == [] do
      :ok
    else
      statuses =
        Map.new(missing, fn name ->
          {name, get_in(runtime, [name, :status]) || :unverified}
        end)

      {:error,
       %Error{
         type: :runtime_capability,
         message: "Required runtime capabilities are not supported: #{inspect(missing)}",
         details: %{missing: missing, statuses: statuses}
       }}
    end
  end

  def check(_, _),
    do:
      {:error,
       Error.invalid_request(["runtime_requirements"], "must be a list of capability atoms")}

  @spec require!(Client.t() | Pristine.Client.t() | Pristine.Core.Context.t(), [atom()]) :: :ok
  def require!(client, requirements) do
    case check(client, requirements) do
      :ok -> :ok
      {:error, error} -> raise error
    end
  end

  defp pristine_source(%Client{pristine_client: %Pristine.Client{} = client}), do: client
  defp pristine_source(%Pristine.Client{} = client), do: client
  defp pristine_source(%Pristine.Core.Context{} = context), do: context
end
