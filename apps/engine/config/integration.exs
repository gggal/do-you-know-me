import Config

config :engine, user: Server.User
config :engine, game: Server.Game
config :engine, invitation: Server.Invitation
config :engine, question: Server.Question
config :engine, score: Server.Score
config :engine, client: Client.Worker
config :engine, server_worker: Server.Worker

config :engine, DB.Repo,
  database: "dykm_repo_test",
  username: "dykm_user",
  password: "dykm_password",
  hostname: "localhost"

config :engine, ecto_repos: [DB.Repo]

config :logger, :engine_error_log,
  path: "engine_test.log",
  format: {Formatter, :format},
  metadata: [:file, :function, :line],
  level: :info
