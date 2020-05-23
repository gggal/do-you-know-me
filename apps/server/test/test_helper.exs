Server.Cluster.spawn()
Application.ensure_all_started(:mox)
ExUnit.start(exclude: [:skip])

Mox.defmock(Application.get_env(:server, :user), for: User)
Mox.defmock(Application.get_env(:server, :game), for: Game)
Mox.defmock(Application.get_env(:server, :question), for: Question)
Mox.defmock(Application.get_env(:server, :invitation), for: Invitation)
Mox.defmock(Application.get_env(:server, :score), for: Score)

defmodule TestUtil do
  def random_username, do: "#{:rand.uniform(1_000_000_000)}"
end
