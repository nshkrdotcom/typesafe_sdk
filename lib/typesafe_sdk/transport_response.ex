defmodule TypeSafeSDK.TransportResponse do
  @moduledoc false

  alias Pristine.Response

  @type t :: %__MODULE__{
          data: term(),
          raw_http_response: Response.t(),
          request_id: String.t() | nil,
          retries: non_neg_integer(),
          elapsed_ms: non_neg_integer()
        }

  @enforce_keys [:data, :raw_http_response]
  defstruct [:data, :raw_http_response, :request_id, retries: 0, elapsed_ms: 0]

  @spec new(Pristine.SDK.Response.t() | map(), keyword()) :: t()
  def new(%{status: _status} = response, opts) when is_list(opts) do
    raw = Response.from_transport(response)

    %__MODULE__{
      data: Keyword.get(opts, :data),
      raw_http_response: raw,
      request_id: header(raw.headers, "x-typesafe-request-id"),
      retries: Keyword.get(opts, :retries, 0),
      elapsed_ms: Keyword.get(opts, :elapsed_ms, 0)
    }
  end

  defp header(headers, target) when is_map(headers) or is_list(headers) do
    target = String.downcase(target)

    Enum.find_value(headers, fn {name, value} ->
      if String.downcase(to_string(name)) == target, do: to_string(value)
    end)
  end

  defp header(_headers, _target), do: nil
end
