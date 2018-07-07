Code.load_file("test/server/cluster.ex")
# Code.load_file("test/server/test_client.ex")
Server.Cluster.spawn()
ExUnit.start(exclude: [:skip])
