defmodule TypeSafeSDK.TransportError do
  @moduledoc false

  def timeout?(reason)
      when reason in [
             :timeout,
             :request_timeout,
             :deadline_exceeded,
             :runtime_result_timeout,
             "timeout",
             ":timeout",
             "request_timeout",
             "deadline_exceeded"
           ],
      do: true

  def timeout?({:timeout, _detail}), do: true
  def timeout?({:error, reason}), do: timeout?(reason)
  def timeout?({:execution_plane_transport, failure, raw}), do: timeout?(failure) or timeout?(raw)
  def timeout?(%{reason: reason}), do: timeout?(reason)
  def timeout?(%{error: reason}), do: timeout?(reason)
  def timeout?(%{raw_payload: raw}), do: timeout?(raw)
  def timeout?(%{kind: kind}), do: timeout?(kind)
  def timeout?(_reason), do: false
end
