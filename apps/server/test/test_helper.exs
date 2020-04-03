Code.load_file("test/server/cluster.ex")
# Code.load_file("test/server/test_client.ex")
Server.Cluster.spawn()
ExUnit.start(exclude: [:skip])

defmodule TestUtil do
  def random_username, do: "#{:rand.uniform(1_000_000_000)}"
end
