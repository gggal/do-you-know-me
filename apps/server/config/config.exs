import Config

config :logger,
  backends: [{LoggerFileBackend, :server_error_log}]

config :logger, :server_error_log,
  path: "app.log",
  # format: "$time $metadata[$level] $message\n",
  format: {Formatter, :format},
  metadata: [:file, :function, :line],
  level: :info

# config :server, first: First

import_config "#{Mix.env()}.exs"
