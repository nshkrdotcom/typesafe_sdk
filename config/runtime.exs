import Config

blank_to_nil = fn
  nil ->
    nil

  value ->
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
end

if api_key = blank_to_nil.(System.get_env("TYPESAFE_API_KEY")) do
  config :typesafe_sdk, api_key: api_key
end

if base_url = blank_to_nil.(System.get_env("TYPESAFE_BASE_URL")) do
  config :typesafe_sdk, base_url: String.trim_trailing(base_url, "/")
end

if model = blank_to_nil.(System.get_env("TYPESAFE_DEFAULT_MODEL")) do
  config :typesafe_sdk, default_model: model
end

if level = blank_to_nil.(System.get_env("TYPESAFE_LOG_LEVEL")) do
  case String.downcase(level) do
    "debug" -> config :typesafe_sdk, log_level: :debug
    "info" -> config :typesafe_sdk, log_level: :info
    "warning" -> config :typesafe_sdk, log_level: :warn
    "warn" -> config :typesafe_sdk, log_level: :warn
    "error" -> config :typesafe_sdk, log_level: :error
    _ -> :ok
  end
end
