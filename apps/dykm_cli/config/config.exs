# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :logger,
  backends: [{LoggerFileBackend, :cli_log}]

config :logger, :cli_log,
  path: "dykm_cli.log",
  level: :error

import_config "../../engine/config/#{Mix.env()}.exs"
