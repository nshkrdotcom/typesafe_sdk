import Config

config :typesafe_sdk,
  api_key: nil,
  base_url: "https://api.typesafe.ai",
  default_model: "jev-latest",
  timeout_ms: 10_000,
  log_level: :warn

import_config "#{config_env()}.exs"
