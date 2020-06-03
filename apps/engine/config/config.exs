import Config

config :logger,
  backends: [{LoggerFileBackend, :engine_error_log}]

import_config "#{Mix.env()}.exs"
