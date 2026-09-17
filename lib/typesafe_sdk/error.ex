defmodule TypeSafeSDK.Error do
  @moduledoc """
  Normalized TypeSafe SDK error.

  HTTP status mapping follows the supplied Python SDK: 400, 401, 403, 404, 422,
  429, and 5xx receive dedicated `type` values; other unsuccessful statuses use
  `:api_error`. Transport and response validation failures are distinct.
  """

  alias Pristine.SDK.ProviderProfile

  @type error_type ::
          :invalid_request
          | :task_exit
          | :runtime_capability
          | :configuration
          | :bad_request
          | :authentication
          | :permission_denied
          | :not_found
          | :unprocessable_entity
          | :rate_limit
          | :internal_server
          | :api_error
          | :connection
          | :timeout
          | :cancelled
          | :response_contract
          | :request_too_large
          | :model_not_found
          | :ambiguous_model
          | :unordered_model_catalog
          | :response_validation

  @type t :: %__MODULE__{
          type: error_type(),
          message: String.t(),
          status: integer() | nil,
          body: term(),
          headers: map(),
          request_id: String.t() | nil,
          retry_after_ms: non_neg_integer() | nil,
          field_path: String.t() | nil,
          path: [String.t()] | nil,
          endpoint: String.t() | nil,
          raw_http_response: Pristine.Response.t() | nil,
          cause: term(),
          prepared_fingerprint: String.t() | nil,
          details: map()
        }

  defexception type: :api_error,
               message: "TypeSafe API error",
               status: nil,
               body: nil,
               headers: %{},
               request_id: nil,
               retry_after_ms: nil,
               field_path: nil,
               path: nil,
               endpoint: nil,
               raw_http_response: nil,
               cause: nil,
               prepared_fingerprint: nil,
               details: %{}

  @doc "A local request validation failure, with unambiguous path components."
  @spec invalid_request([String.t()], String.t(), map()) :: t()
  def invalid_request(path, reason, details \\ %{}) do
    %__MODULE__{
      type: :invalid_request,
      path: path,
      field_path: Enum.join(path, "."),
      message: "Invalid request at #{inspect(path)}: #{reason}",
      details: Map.put(details, :reason, reason)
    }
  end

  @doc false
  def invalid_response(path, reason, body \\ nil) do
    %__MODULE__{
      type: :response_validation,
      path: path,
      field_path: Enum.join(path, "."),
      message: "Invalid response at #{inspect(path)}: #{reason}",
      body: body,
      details: %{reason: reason}
    }
  end

  @doc "Stable, bounded structural metadata safe for telemetry and diagnostics."
  @spec metadata(t()) :: map()
  def metadata(%__MODULE__{} = error) do
    %{
      type: error.type,
      code: error.type,
      status: error.status,
      request_id: bounded_identifier(error.request_id),
      retry_after_ms: error.retry_after_ms,
      retriable: retryable?(error),
      cancelled: error.type == :cancelled,
      field_path: bounded_identifier(error.field_path),
      response_contract: response_contract_metadata(error),
      request_budget: request_budget_metadata(error),
      prepared_fingerprint: error.prepared_fingerprint
    }
  end

  @doc false
  @spec with_prepared_fingerprint(t(), String.t()) :: t()
  def with_prepared_fingerprint(%__MODULE__{} = error, fingerprint) when is_binary(fingerprint),
    do: %{error | prepared_fingerprint: fingerprint}

  @doc false
  @spec cancelled(Pristine.Error.t()) :: t()
  def cancelled(%Pristine.Error{type: :cancelled} = cause) do
    %__MODULE__{
      type: :cancelled,
      message: "Request was cancelled",
      request_id: cause.request_id,
      retry_after_ms: nil,
      cause: cause,
      details: %{cancelled: true}
    }
  end

  @doc false
  @spec request_too_large(non_neg_integer(), pos_integer()) :: t()
  def request_too_large(actual_bytes, max_bytes) do
    %__MODULE__{
      type: :request_too_large,
      message: "Serialized request exceeds max_request_bytes",
      details: %{actual_bytes: actual_bytes, max_bytes: max_bytes}
    }
  end

  @doc false
  @spec response_contract(atom(), map()) :: t()
  def response_contract(violation, details \\ %{}) do
    %__MODULE__{
      type: :response_contract,
      message: "Response contract violation: #{violation}",
      details: Map.put(details, :violation, violation)
    }
  end

  @doc false
  def model_lookup(type, identifier, details \\ %{})
      when type in [:model_not_found, :ambiguous_model] do
    %__MODULE__{
      type: type,
      message: "Model lookup failed: #{type}",
      details: Map.merge(%{identifier: bounded_identifier(identifier)}, details)
    }
  end

  @doc false
  def unordered_model_catalog(details \\ %{}) do
    %__MODULE__{
      type: :unordered_model_catalog,
      message: "Model catalog has no unambiguous objective latest ordering",
      details: details
    }
  end

  @doc "Whether the error is eligible under the given retry policy (default: SDK default)."
  @spec retryable?(t(), TypeSafeSDK.RetryPolicy.t() | false) :: boolean()
  def retryable?(error, policy \\ %TypeSafeSDK.RetryPolicy{})
  def retryable?(_error, false), do: false
  def retryable?(%__MODULE__{details: %{scope: :batch}}, _policy), do: false
  def retryable?(%__MODULE__{type: :connection}, policy), do: policy.api_connection_error
  def retryable?(%__MODULE__{type: :timeout}, policy), do: policy.api_timeout_error

  def retryable?(%__MODULE__{status: status, type: type}, policy)
      when is_integer(status) and type not in [:response_validation, :invalid_request],
      do: Enum.member?(policy.http_statuses, status)

  def retryable?(%__MODULE__{}, _policy), do: false

  @doc "Retry-After advice in milliseconds, when supplied by the service."
  @spec retry_after(t()) :: non_neg_integer() | nil
  def retry_after(%__MODULE__{retry_after_ms: value}), do: value

  @spec configuration(String.t()) :: t()
  def configuration(message) when is_binary(message) do
    %__MODULE__{type: :configuration, message: message}
  end

  @spec response_validation(String.t() | [String.t()], term()) :: t()
  def response_validation(field_path, body \\ nil)

  def response_validation(path, body) when is_list(path) do
    field_path = Enum.join(path, ".")

    %__MODULE__{
      type: :response_validation,
      message: "Invalid response data at #{inspect(field_path)}",
      field_path: field_path,
      path: path,
      body: body
    }
  end

  def response_validation(field_path, body) when is_binary(field_path) do
    error = response_validation(String.split(field_path, "."), body)
    %{error | field_path: field_path}
  end

  @doc false
  @spec from_response(Pristine.SDK.Response.t() | map(), term(), non_neg_integer() | nil, keyword()) ::
          t()
  def from_response(%{status: status} = response, body, retry_after_ms, opts) do
    profile = Keyword.get(opts, :profile)
    headers = normalize_headers(response.headers)

    request_id =
      ProviderProfile.request_id(profile, body, headers) ||
        header(headers, "x-typesafe-request-id")

    endpoint = endpoint(response)
    detail = extract_message(body) || fallback_message(body)

    %__MODULE__{
      type: status_type(status),
      status: status,
      body: body,
      headers: headers,
      request_id: request_id,
      retry_after_ms: retry_after_ms || parse_retry_after(headers),
      endpoint: endpoint,
      raw_http_response: Pristine.Response.from_transport(response),
      message: format_message(endpoint, status, detail, request_id)
    }
  end

  @doc false
  @spec attach_response(t(), Pristine.Response.t() | nil, term()) :: t()
  def attach_response(%__MODULE__{} = error, %Pristine.Response{} = response, decoded_body) do
    headers = normalize_headers(response.headers)
    request_id = header(headers, "x-typesafe-request-id")
    endpoint = endpoint_from_metadata(response.metadata)

    detail =
      case error.type do
        :response_validation -> "Invalid response data at #{inspect(error.field_path)}."
        _other -> error.message
      end

    %{
      error
      | status: response.status,
        body: decoded_body,
        headers: headers,
        request_id: request_id,
        endpoint: endpoint,
        raw_http_response: response,
        message: format_message(endpoint, response.status, detail, request_id)
    }
  end

  def attach_response(%__MODULE__{} = error, nil, decoded_body), do: %{error | body: decoded_body}

  @doc false
  def connection_error(reason, _opts \\ []) do
    if TypeSafeSDK.TransportError.timeout?(reason) do
      timeout_error()
    else
      %__MODULE__{
        type: :connection,
        message: "Connection error: #{format_reason(reason)}",
        details: %{reason: reason}
      }
    end
  end

  @doc false
  def timeout_error do
    %__MODULE__{type: :timeout, message: "Request timed out"}
  end

  @doc false
  def validation_error(reason, body, _opts \\ []) do
    %__MODULE__{
      type: :response_validation,
      message: "Response validation failed: #{format_reason(reason)}",
      body: body,
      details: %{reason: reason}
    }
  end

  @spec parse_retry_after(map() | list()) :: non_neg_integer() | nil
  def parse_retry_after(headers) do
    headers = normalize_headers(headers)

    case parse_nonnegative_number(header(headers, "retry-after-ms"), 1) do
      nil -> parse_retry_after_seconds(header(headers, "retry-after"))
      value -> value
    end
  end

  @spec extract_message(term()) :: String.t() | nil
  def extract_message(body) when is_binary(body), do: if(body == "", do: nil, else: body)

  def extract_message(body) when is_map(body) do
    error_message(get(body, "error")) || string_message(get(body, "message")) ||
      detail_message(get(body, "detail"))
  end

  def extract_message(_body), do: nil

  defp error_message(value) when is_map(value), do: string_message(get(value, "message"))
  defp error_message(value), do: string_message(value)
  defp string_message(value) when is_binary(value), do: value
  defp string_message(_value), do: nil
  defp detail_message(value) when is_list(value), do: validation_detail_message(value)
  defp detail_message(value), do: error_message(value)

  defp validation_detail_message(entries) do
    entries
    |> Enum.flat_map(fn
      entry when is_map(entry) ->
        case get(entry, "msg") do
          msg when is_binary(msg) ->
            path =
              entry
              |> get("loc")
              |> List.wrap()
              |> Enum.reject(&(&1 == "body"))
              |> Enum.map_join(".", &to_string/1)

            [if(path == "", do: msg, else: "#{path}: #{msg}")]

          _ ->
            []
        end

      _ ->
        []
    end)
    |> Enum.join("; ")
    |> case do
      "" -> nil
      message -> message
    end
  end

  defp fallback_message(nil), do: "status code (no body)"
  defp fallback_message(body) when is_binary(body), do: truncate(body)

  defp fallback_message(body) do
    case Jason.encode(body) do
      {:ok, encoded} -> truncate(encoded)
      {:error, _} -> truncate(inspect(body))
    end
  end

  defp truncate(value) when byte_size(value) <= 200, do: value
  defp truncate(value), do: binary_part(value, 0, 200) <> "..."

  defp status_type(400), do: :bad_request
  defp status_type(401), do: :authentication
  defp status_type(403), do: :permission_denied
  defp status_type(404), do: :not_found
  defp status_type(422), do: :unprocessable_entity
  defp status_type(429), do: :rate_limit
  defp status_type(status) when is_integer(status) and status >= 500, do: :internal_server
  defp status_type(_status), do: :api_error

  defp format_message(endpoint, status, detail, request_id) do
    status_message = [status, detail] |> Enum.reject(&is_nil/1) |> Enum.join(" ")
    endpoint_message = if endpoint, do: "#{endpoint}: #{status_message}", else: status_message
    if request_id, do: "#{endpoint_message} (request_id=#{request_id})", else: endpoint_message
  end

  defp endpoint(%{metadata: metadata}), do: endpoint_from_metadata(metadata)
  defp endpoint(_response), do: nil

  defp endpoint_from_metadata(metadata) when is_map(metadata) do
    method = Map.get(metadata, :method) || Map.get(metadata, "method")
    url = Map.get(metadata, :url) || Map.get(metadata, "url")

    if method && url do
      "#{method |> to_string() |> String.upcase()} #{strip_query_fragment(to_string(url))}"
    end
  end

  defp endpoint_from_metadata(_metadata), do: nil

  defp strip_query_fragment(url) do
    uri = URI.parse(url)
    URI.to_string(%{uri | query: nil, fragment: nil})
  end

  defp response_contract_metadata(%__MODULE__{type: :response_contract, details: details}) do
    details
    |> Map.take([:violation, :answer_key, :model, :allowed_model_count])
  end

  defp response_contract_metadata(_error), do: nil

  defp request_budget_metadata(%__MODULE__{type: :request_too_large, details: details}) do
    case {Map.get(details, :actual_bytes), Map.get(details, :max_bytes)} do
      {actual, maximum} when is_integer(actual) and is_integer(maximum) ->
        %{actual_bytes: actual, max_bytes: maximum}

      _ ->
        nil
    end
  end

  defp request_budget_metadata(_error), do: nil

  defp bounded_identifier(nil), do: nil
  defp bounded_identifier(value) when is_binary(value) and byte_size(value) <= 128, do: value
  defp bounded_identifier(value) when is_binary(value), do: String.slice(value, 0, 128)
  defp bounded_identifier(value) when is_atom(value) or is_integer(value), do: to_string(value)
  defp bounded_identifier(_value), do: "<invalid>"

  defp parse_retry_after_seconds(nil), do: nil

  defp parse_retry_after_seconds(value) do
    parse_nonnegative_number(value, 1_000) || parse_http_date(value)
  end

  defp parse_nonnegative_number(nil, _multiplier), do: nil

  defp parse_nonnegative_number(value, multiplier) do
    case Float.parse(String.trim(to_string(value))) do
      {number, ""} when number >= 0 -> round(number * multiplier)
      _ -> nil
    end
  end

  defp parse_http_date(value) when is_binary(value) do
    with date_tuple when is_tuple(date_tuple) <-
           :httpd_util.convert_request_date(String.to_charlist(value)),
         seconds when is_integer(seconds) <- :calendar.datetime_to_gregorian_seconds(date_tuple) do
      now = :calendar.datetime_to_gregorian_seconds(:calendar.universal_time())
      max(seconds - now, 0) * 1_000
    else
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp parse_http_date(_value), do: nil

  defp normalize_headers(headers) when is_map(headers) do
    Map.new(headers, fn {key, value} -> {String.downcase(to_string(key)), to_string(value)} end)
  end

  defp normalize_headers(headers) when is_list(headers) do
    Map.new(headers, fn {key, value} -> {String.downcase(to_string(key)), to_string(value)} end)
  end

  defp normalize_headers(_headers), do: %{}
  defp header(headers, name), do: Map.get(headers, String.downcase(name))
  defp get(map, key), do: Map.get(map, key) || Map.get(map, known_atom_key(key))

  defp known_atom_key("error"), do: :error
  defp known_atom_key("message"), do: :message
  defp known_atom_key("detail"), do: :detail
  defp known_atom_key("msg"), do: :msg
  defp known_atom_key("loc"), do: :loc
  defp known_atom_key(_key), do: :__typesafe_missing_key__

  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason(reason) when is_atom(reason), do: Atom.to_string(reason)

  defp format_reason(reason) do
    if is_exception(reason), do: Exception.message(reason), else: inspect(reason)
  end
end
