import Config

config :logger,
  backends: [{LoggerFileBackend, :server_error_log}]

import_config "#{Mix.env()}.exs"
