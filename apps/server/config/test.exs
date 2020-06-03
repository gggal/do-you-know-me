import Config

config :server, user: UserMock
config :server, game: GameMock
config :server, invitation: InvitationMock
config :server, question: QuestionMock
config :server, score: ScoreMock
config :server, client: ClientMock
config :server, server_worker: ServerMock

config :server, db_name: :server

config :server, DB.Repo,
  database: "dykm_repo_test",
  username: "dykm_user",
  password: "dykm_password",
  hostname: "localhost"

config :server, ecto_repos: [DB.Repo]

config :logger, :server_error_log,
  path: "server_test.log",
  format: {Formatter, :format},
  metadata: [:file, :function, :line],
  level: :info
