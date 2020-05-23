import Config

config :logger,
  backends: [{LoggerFileBackend, :server_error_log}]

config :logger, :server_error_log,
  path: "server.log",
  format: {Formatter, :format},
  metadata: [:file, :function, :line],
  level: :info

import_config "#{Mix.env()}.exs"
