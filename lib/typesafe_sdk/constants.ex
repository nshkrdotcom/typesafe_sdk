defmodule TypeSafeSDK.Constants do
  @moduledoc "Public defaults and environment variable names shared with the Python SDK."

  @api_key_env "TYPESAFE_API_KEY"
  @base_url_env "TYPESAFE_BASE_URL"
  @default_model_env "TYPESAFE_DEFAULT_MODEL"
  @log_level_env "TYPESAFE_LOG_LEVEL"
  @default_base_url "https://api.typesafe.ai"
  @default_model "jev-latest"
  @default_timeout_ms 10_000

  def api_key_env, do: @api_key_env
  def base_url_env, do: @base_url_env
  def default_model_env, do: @default_model_env
  def log_level_env, do: @log_level_env
  def default_base_url, do: @default_base_url
  def default_model, do: @default_model
  def default_timeout_ms, do: @default_timeout_ms
end
