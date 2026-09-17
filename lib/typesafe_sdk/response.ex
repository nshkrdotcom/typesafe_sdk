defmodule TypeSafeSDK.Response do
  @moduledoc "Answer accessors and bounded metadata for TypeSafe responses."

  alias TypeSafeSDK.{ListModelsResponse, SystemOneResponse}

  defdelegate fetch(response, id), to: SystemOneResponse
  defdelegate fetch!(response, id), to: SystemOneResponse
  defdelegate nouls(response), to: SystemOneResponse
  defdelegate choices(response), to: SystemOneResponse
  defdelegate scores(response), to: SystemOneResponse
  defdelegate request_id!(response), to: SystemOneResponse
  defdelegate raw_http_response!(response), to: SystemOneResponse

  @doc "Return stable structural metadata without raw request/response content."
  @spec metadata(SystemOneResponse.t() | ListModelsResponse.t()) :: map()
  def metadata(%SystemOneResponse{} = response) do
    %{
      model: bounded(response.model),
      request_id: bounded(response.request_id),
      usage: usage_metadata(response.usage),
      retries: response.retries,
      retry_count: response.retries,
      elapsed_ms: response.elapsed_ms,
      runtime_elapsed_ms: response.runtime_elapsed_ms,
      batch_index: response.batch_index,
      prepared_fingerprint: response.prepared_fingerprint
    }
  end

  def metadata(%ListModelsResponse{} = response) do
    %{
      model: nil,
      request_id: bounded(response.request_id),
      usage: nil,
      retries: response.retries,
      retry_count: response.retries,
      elapsed_ms: response.elapsed_ms,
      runtime_elapsed_ms: nil,
      batch_index: nil,
      prepared_fingerprint: nil
    }
  end

  defp usage_metadata(nil), do: nil

  defp usage_metadata(%{input_tokens: input, output_tokens: output}),
    do: %{input_tokens: input, output_tokens: output}

  defp bounded(nil), do: nil
  defp bounded(value) when is_binary(value) and byte_size(value) <= 256, do: value
  defp bounded(value) when is_binary(value), do: String.slice(value, 0, 256)
  defp bounded(_value), do: nil
end
