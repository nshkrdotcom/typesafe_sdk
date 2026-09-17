defmodule TypeSafeSDK.RuntimeCapabilities do
  @moduledoc """
  Fail-closed reporting of transport capabilities, without inventing Pristine APIs.

  The supplied Pristine integration establishes no contract for global queue
  bounds, a streaming response-byte cap, or physical cancellation cleanup.
  Missing capabilities report `:unverified`, not `false` or "supported".

  An adapter may implement `typesafe_capabilities(transport_opts)` (preferred) or
  `typesafe_capabilities/0`, returning a map. Numeric bounds are positive integers
  (`bounded_queue` also accepts zero); `deterministic_overload` and
  `cancellation_cleanup` must be `true`. Reports label these **advertised**, not
  independently verified. Adapter contract tests must prove actual enforcement.
  """
  alias TypeSafeSDK.Error
  @capabilities [:bounded_outstanding_requests, :bounded_queue, :max_response_bytes,
                 :deterministic_overload, :cancellation_cleanup]

  @spec names() :: [atom()]
  def names, do: @capabilities

  @spec report(TypeSafeSDK.Client.t() | map()) :: map()
  def report(%{transport: transport, transport_opts: opts}) do
    advertised = advertisement(transport, opts)
    runtime = Map.new(@capabilities, fn name ->
      value = Map.get(advertised, name)
      result = if valid?(name, value), do: %{status: :advertised, value: value}, else: :unverified
      {name, result}
    end)
    %{transport: inspect(transport), runtime: runtime,
      sdk: %{batch_concurrency: :bounded_per_enumeration, batch_queue: :lazy_enumeration,
        ordered_prefetch: :bounded_windows,
        batch_cancellation: :owned_tasks_only},
      assurance: :adapter_advertisement_requires_contract_tests}
  end

  @spec check(TypeSafeSDK.Client.t(), [atom()]) :: :ok | {:error, Error.t()}
  def check(_client, []), do: :ok

  def check(client, requirements) when is_list(requirements) do
    runtime = report(client).runtime
    missing = Enum.reject(requirements, fn name ->
      name in @capabilities and match?(%{status: :advertised}, Map.get(runtime, name))
    end)
    if missing == [], do: :ok,
      else: {:error, %Error{type: :runtime_capability,
        message: "Required runtime capabilities are not advertised: #{inspect(missing)}",
        details: %{missing: missing, assurance: :unverified}}}
  end
  def check(_, _), do: {:error, Error.invalid_request(["runtime_requirements"], "must be a list of capability atoms")}

  @spec require!(TypeSafeSDK.Client.t(), [atom()]) :: :ok
  def require!(client, requirements) do
    case check(client, requirements) do
      :ok -> :ok
      {:error, error} -> raise error
    end
  end

  defp advertisement(transport, opts) do
    if Code.ensure_loaded?(transport) do
      result = cond do
        function_exported?(transport, :typesafe_capabilities, 1) -> transport.typesafe_capabilities(opts)
        function_exported?(transport, :typesafe_capabilities, 0) -> transport.typesafe_capabilities()
        true -> %{}
      end
      if is_map(result) and not is_struct(result), do: result, else: %{}
    else
      %{}
    end
  rescue
    _ -> %{}
  catch
    _, _ -> %{}
  end
  defp valid?(:bounded_queue, value), do: is_integer(value) and value >= 0
  defp valid?(name, value) when name in [:bounded_outstanding_requests, :max_response_bytes],
    do: is_integer(value) and value > 0
  defp valid?(_, value), do: value == true
end
