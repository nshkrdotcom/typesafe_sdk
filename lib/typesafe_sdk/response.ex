defmodule TypeSafeSDK.Response do
  @moduledoc "Answer accessors for the single public `TypeSafeSDK.SystemOneResponse` type."
  defdelegate fetch(response, id), to: TypeSafeSDK.SystemOneResponse
  defdelegate fetch!(response, id), to: TypeSafeSDK.SystemOneResponse
  defdelegate nouls(response), to: TypeSafeSDK.SystemOneResponse
  defdelegate choices(response), to: TypeSafeSDK.SystemOneResponse
  defdelegate scores(response), to: TypeSafeSDK.SystemOneResponse
  defdelegate request_id!(response), to: TypeSafeSDK.SystemOneResponse
  defdelegate raw_http_response!(response), to: TypeSafeSDK.SystemOneResponse
end
