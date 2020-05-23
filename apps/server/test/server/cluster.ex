defmodule Server.Cluster do
  def spawn do
    :net_kernel.start([:"first@127.0.0.1"])

    :erl_boot_server.start([])
    {:ok, ipv4} = :inet.parse_ipv4_address('127.0.0.1')
    :erl_boot_server.add_slave(ipv4)

    nodes = [:node1, :node2, :node3]

    nodes
    |> Enum.map(&Task.async(fn -> spawn_node(&1) end))
    |> Enum.map(&Task.await(&1, 30_000))
  end

  defp spawn_node(node_host) do
    {:ok, node} = :slave.start(to_charlist("127.0.0.1"), node_host, inet_loader_args())
    :ok = add_code_paths(node)
    ensure_dummy_client_started(node)
    {:ok, node}
  end

  def rpc(node, module, function, args) do
    :rpc.block_call(node, module, function, args)
  end

  defp inet_loader_args do
    to_charlist("-loader inet -hosts 127.0.0.1 -setcookie #{:erlang.get_cookie()}")
  end

  defp add_code_paths(node) do
    Code.require_file("test/server/test_client.exs")
    rpc(node, :code, :add_paths, [:code.get_path()])
  end

  defp ensure_dummy_client_started(node) do
    rpc(node, Application, :ensure_all_started, [:mix])
    rpc(node, Mix, :env, [Mix.env()])
    rpc(node, Code, :require_file, "test/server/test_client.exs")

    {:ok, _pid} = rpc(node, Server.TestClient, :start_link, [])
  end
end
