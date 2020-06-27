# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :logger,
  backends: [{LoggerFileBackend, :client_error_log}]

config :logger, :client_error_log,
  path: "client.log",
  level: :error

import_config "../../engine/config/#{Mix.env()}.exs"
