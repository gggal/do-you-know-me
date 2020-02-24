# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :clustered_nodes, nodes: [:"node1@127.0.0.1", :"node2@127.0.0.1", :"node3@127.0.0.1"]

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure your application as:
#
#     config :server, key: :value
#
# and access this configuration in your application as:
#
#     Application.get_env(:server, :key)
#
# You can also configure a 3rd-party app:

config :logger,
  backends: [{LoggerFileBackend, :server_error_log}]

config :logger, :server_error_log,
  path: "app.log",
  # format: "$time $metadata[$level] $message\n",
  format: {Formatter, :format},
  metadata: [:file, :function, :line],
  level: :info

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting tthehe line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env}.exs"
