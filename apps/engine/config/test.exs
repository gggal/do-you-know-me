import Config

config :engine, user: UserMock
config :engine, game: GameMock
config :engine, invitation: InvitationMock
config :engine, question: QuestionMock
config :engine, score: ScoreMock
config :engine, client: ClientMock
config :engine, server_worker: ServerMock

config :engine, db_name: :server

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

config :bcrypt_elixir, log_rounds: 4
