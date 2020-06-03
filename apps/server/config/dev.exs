import Config

# todo rename app to engine
config :server, user: Server.User
config :server, game: Server.Game
config :server, invitation: Server.Invitation
config :server, question: Server.Question
config :server, score: Server.Score
config :server, client: Client.Worker
config :server, server_worker: Server.Worker

config :server, DB.Repo,
  database: "dykm_repo",
  username: "dykm_user",
  password: "dykm_password",
  hostname: "localhost"

config :server, ecto_repos: [DB.Repo]

config :logger, :server_error_log,
  path: "server.log",
  format: {Formatter, :format},
  metadata: [:file, :function, :line],
  level: :info
