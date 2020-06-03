Code.require_file("test/support/mocks.exs")
Engine.Cluster.spawn()
Application.ensure_all_started(:mox)
ExUnit.start(exclude: [:skip])

Mox.defmock(Application.get_env(:engine, :user), for: User)
Mox.defmock(Application.get_env(:engine, :game), for: Game)
Mox.defmock(Application.get_env(:engine, :question), for: Question)
Mox.defmock(Application.get_env(:engine, :invitation), for: Invitation)
Mox.defmock(Application.get_env(:engine, :score), for: Score)
Mox.defmock(Application.get_env(:engine, :client), for: Client.Behaviour)

defmodule TestUtil do
  def random_username, do: "#{:rand.uniform(1_000_000_000)}"
end
