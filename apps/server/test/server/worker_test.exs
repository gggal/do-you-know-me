defmodule Server.WorkerTest do
  use ExUnit.Case

  require Logger

  def node1(), do: :"node1@127.0.0.1"
  def node2(), do: :"node2@127.0.0.1"
  def node3(), do: :"node3@127.0.0.1"

  setup_all do
    {:ok, _} = Server.Worker.start_link()
    {:ok, _} = :rpc.call(node1(), Server.TestClient, :start_link, [])
    {:ok, _} = :rpc.call(node2(), Server.TestClient, :start_link, [])
    {:ok, _} = :rpc.call(node3(), Server.TestClient, :start_link, [])
    :ok
  end

  # Client1 has sent invitation to client2 and client3.
  setup do
    state()
    :rpc.call(node1(), GenServer, :call, [:quiz_client, :unregister])
    :rpc.call(node2(), GenServer, :call, [:quiz_client, :unregister])
    :rpc.call(node3(), GenServer, :call, [:quiz_client, :unregister])
    :rpc.call(node1(), GenServer, :call, [:quiz_client, {:register, "username1"}])
    :rpc.call(node2(), GenServer, :call, [:quiz_client, {:register, "username2"}])
    :rpc.call(node3(), GenServer, :call, [:quiz_client, {:register, "username3"}])

    :rpc.block_call(node3(), GenServer, :cast, [:quiz_client, {:invite, "username2"}])
    :rpc.block_call(node2(), GenServer, :cast, [:quiz_client, {:invite, "username3"}])
    :rpc.block_call(node1(), GenServer, :cast, [:quiz_client, {:invite, "username2"}])
    state()
  end

  # @tag :skip
  test "successfully registering a client" do
    # Logger.info state()
    # :unregistered = :rpc.call(node1(), GenServer, :call, [:quiz_client, :unregister])
    :unregistered == remote_call(node1(), :unregister)

    # assert :registered == :rpc.call(node1(), GenServer, :call, [:quiz_client, {:register, "username1"}])
    assert :registered == remote_call(node1(), {:register, "username1"})
  end

  # @tag :skip
  test "failing to register already registered client" do
    # assert :already_registered == :rpc.call(node1(), GenServer, :call, [:quiz_client, {:register, "username1"}])
    assert :already_registered == remote_call(node1(), {:register, "username1"})
  end

  # @tag :skip
  test "failing to register a client with already taken name" do
    # :rpc.call(node1(), GenServer, :call, [:quiz_client, :unregister])
    remote_call(node1(), :unregister)

    # assert :taken == :rpc.call(node1(), GenServer, :call, [:quiz_client, {:register, "username2"}])
    assert :taken == remote_call(node1(), {:register, "username2"})
  end

  # @tag :skip
  test "successfully unregistering a client" do
    # assert :unregistered == :rpc.call(node1(), GenServer, :call, [:quiz_client, :unregister])
    assert :unregistered == remote_call(node1(), :unregister)
  end

  # @tag :skip
  test "failing to unregister an unregistered client" do
    # :rpc.call(node1(), GenServer, :call, [:quiz_client, :unregister])
    remote_call(node1(), :unregister)
    assert :not_registered == :rpc.call(node1(), GenServer, :call, [:quiz_client, :unregister])
  end

  @tag :skip
  test "disconnecting of a client" do
    GenServer.call({:global, :quiz_server}, {:register, "username1"})
    # send {:global, :quiz_server} {:DOWN,_ref, :"client1@??", _pid, _reason}
    clients = GenServer.call({:global, :quiz_server}, :list_registered)
    assert false == Enum.member?(clients, "username1")
  end

  @tag :skip
  test "reconnecting of a client" do
    GenServer.call({:global, :quiz_server}, {:register, "username1"})
    # GenServer.info(..)
    clients = GenServer.call({:global, :quiz_server}, {:list_registered})
    # GenServer.info(..)
    assert Map.contains_key?(clients, "username1")
  end

  # @tag :skip
  test "returning list of registered clients" do
    # list = :rpc.call(node1(), GenServer, :call, [:quiz_client, :list_registered])
    list = remote_call(node1(), :list_registered)
    assert [] == ["username1", "username2", "username3"] -- list
  end

  test "returning empty list of related players before the game has started" do
    assert [] = remote_call(node1(), :list_related)
  end

  test "returning non-empty list of related players after the game has started" do
    remote_cast(node2(), {:accept, "username1"})
    assert ["username1"] == remote_call(node2(), :list_related)
  end

  # @tag :skip
  test "newly registered client hasn't played with anyone yet" do
    # assert [] == :rpc.call(node1(), GenServer, :call, [:quiz_client, :get_rating])
    assert [] == remote_call(node1(), :get_rating)
  end

  # @tag :skip
  test "returning rate after playing with another client" do
    # :rpc.call(node2(), GenServer, :cast, [:quiz_client, {:answer, "username3", :a}])
    remote_cast(node2(), {:answer, "username3", :a})
    # :rpc.call(node3(), GenServer, :call, [:quiz_client, {:guess, :right, "username2", :a}])
    remote_call(node3(), {:guess, :right, "username2", :a})

    assert [{"username2", 100.0, 100.0}] ==
             :rpc.call(node3(), GenServer, :call, [:quiz_client, :get_rating])
  end

  @tag :skip
  test "returning rate after the player was disconnected" do
    GenServer.call({:global, :quiz_server}, {:unregister, "client1"})
    GenServer.call({:global, :quiz_server}, {:register, "client1"})
    # GenServer.info(..)
    assert GenServer.call({:global, :quiz_server}, {:rate, "client1"}) == 0
  end

  # @tag :skip
  test "unregistered client is trying to send an invitation" do
    # :rpc.call(node1(), GenServer, :call, [:quiz_client, :unregister])
    remote_call(node1(), :unregister)
    state1 = state()
    # :rpc.call(node1(), GenServer, :cast, [:quiz_client, {:invite, "username2"}])
    remote_cast(node1(), {:invite, "username2"})
    assert state1 == state()
  end

  # @tag :skip
  test "client is sending an invitation to an unregistered client" do
    # :rpc.call(node1(), GenServer, :cast, [:quiz_client, {:invite, "username4"}])
    remote_cast(node1(), {:invite, "username4"})
    assert Map.get(state(), "username1") |> Map.get("username4") == nil
  end

  @tag :skip
  test "client2 is sending an invitation to client3 who has already sent invitation to client2" do
    client2_map = Map.get(state(), "username2", %{})
    client3_map = Map.get(state(), "username3", %{})
    assert Map.has_key?(client2_map, "username3") && Map.has_key?(client3_map, "username2")
  end

  @tag :skip
  test "client is successfully sending an invitation" do
    assert true == state() |> Map.get("username1", %{}) |> Map.has_key?("username2")
  end

  # @tag :skip
  test "client is trying to accept an invitation from unregistered client" do
    # :rpc.call(node1(), GenServer, :cast, [:quiz_client, {:accept, "username4"}])
    remote_cast(node1(), {:accept, "username4"})
    assert false == Map.get(state(), "username1", %{}) |> Map.has_key?("username4")
  end

  @tag :skip
  test "client is trying to accept an invitation from disconnected client" do
    GenServer.call({:global, :quiz_server}, {:register, "client1"})
    GenServer.call({:global, :quiz_server}, {:register, "client2"})
    GenServer.cast({:global, :quiz_server}, {:invite, "client2", "client1"})
    # GenSever.info(..)
    GenServer.cast({:global, :quiz_server}, {:accept, "client1", "client2"})
    assert %{} = :sys.get_state(:quiz_server)
  end

  # @tag :skip
  test "client is trying to accept an invitation from someone who never sent one" do
    # :rpc.call(node1(), GenServer, :cast, [:quiz_client, {:accept, "username3"}])
    remote_cast(node1(), {:accept, "username3"})
    assert false == Map.get(state(), "username1", %{}) |> Map.has_key?("username3")
  end

  @tag :skip
  test "client is accepting an invitation" do
    # :rpc.call(node2(), GenServer, :cast, [:quiz_client, {:accept, "username1"}])
    remote_cast(node2(), {:accept, "username1"})
    client1_map = Map.get(state(), "username1", %{})
    client2_map = Map.get(state(), "username2", %{})
    assert Map.has_key?(client2_map, "username1") && Map.has_key?(client1_map, "username2")
  end

  # @tag :skip
  test "client is trying to decline an invitation from unregistered client" do
    # :rpc.call(node1(), GenServer, :cast, [:quiz_client, {:decline, "username4"}])
    remote_cast(node1(), {:decline, "username4"})
    assert false == Map.get(state(), "username1", %{}) |> Map.has_key?("username4")
  end

  @tag :skip
  test "client is trying to decline an invitation from disconnected client" do
    GenServer.call({:global, :quiz_server}, {:register, "client1"})
    GenServer.call({:global, :quiz_server}, {:register, "client2"})
    GenServer.cast({:global, :quiz_server}, {:invite, "client2", "client1"})
    # GenSever.info(..)
    GenServer.cast({:global, :quiz_server}, {:accept, "client1", "client2"})
    assert %{} = :sys.get_state(:quiz_server)
  end

  # @tag :skip
  test "client is trying to decline an invitation from someone who never sent one" do
    # :rpc.call(node1(), GenServer, :cast, [:quiz_client, {:decline, "username3"}])
    remote_cast(node1(), {:decline, "username3"})
    assert false == Map.get(state(), "username1", %{}) |> Map.has_key?("username3")
  end

  # @tag :skip
  test "client is declining an invitation" do
    # :rpc.call(node2(), GenServer, :cast, [:quiz_client, {:decline, "username1"}])
    remote_cast(node2(), {:decline, "username1"})
    Process.sleep(1000)
    client1_map = Map.get(state(), "username1", %{}) |> Map.has_key?("username2")
    client2_map = Map.get(state(), "username2", %{}) |> Map.has_key?("username1")
    assert false == client1_map && client2_map == false
  end

  @tag :skip
  test "client is trying to answer a question from a disconnected client" do
    GenServer.call({:global, :quiz_server}, {:register, "client1"})
    GenServer.call({:global, :quiz_server}, {:register, "client2"})
    GenServer.cast({:global, :quiz_server}, {:invite, "client2", "client1"})
    GenServer.cast({:global, :quiz_server}, {:accept, "client1", "client2"})
    # GenSever.info(..)
    # fixthis
    GenServer.call({:global, :quiz_server}, {:answer, "client2", "client2"})
    assert %{"client1" => "client2", "client2" => "client1"} = :sys.get_state(:quiz_server)
  end

  @tag :skip
  test "client is trying to answer a question from an unregistered client" do
    # :rpc.call(node1(), GenServer, :cast, [:quiz_client, {:answer, "username4", :a}])
    remote_cast(node1(), {:answer, "username4", :a})
    assert nil == Map.get(state(), "username1", %{}) |> Map.has_key?("username4")
  end

  @tag :skip
  test "client is trying to guess an answer from an unregistered client" do
    # :rpc.call(node1(), GenServer, :cast, [:quiz_client, {:guess, "username4", :a}])
    remote_cast(node1(), {:guess, "username4", :a})
    assert nil == Map.get(state(), "username1", %{}) |> Map.has_key?("username4")
  end

  @tag :skip
  test "client gives right quess to other client" do
    # :rpc.call(node2(), GenServer, :cast, [:quiz_client, {:answer, "username3", :a}])
    remote_cast(node2(), {:answer, "username3", :a})
    # :rpc.call(node3(), GenServer, :call, [:quiz_client, {:guess, :right, "username2", :a}])
    remote_call(node2(), {:guess, :right, "username2", :a})
    assert {1, 0} == Map.get(state(), "username2") |> Map.get("username3")
  end

  # @tag :skip
  test "client gives wrong quess to other client" do
    # :rpc.call(node2(), GenServer, :cast, [:quiz_client, {:answer, "username3", :a}])
    remote_cast(node2(), {:answer, "username3", :a})
    # :rpc.call(node3(), GenServer, :call, [:quiz_client, {:guess, :wrong, "username2", :b}])
    remote_call(node3(), {:guess, :wrong, "username2", :b})
    assert {0, 1} == Map.get(state(), "username2") |> Map.get("username3")
  end

  # todo reconnect tests

  defp remote_call(node, args) do
    :rpc.call(node, GenServer, :call, [:quiz_client, args])
  end

  defp remote_cast(node, args) do
    :rpc.call(node, GenServer, :cast, [:quiz_client, args])
  end

  defp state() do
    :quiz_server
    |> :global.whereis_name()
    |> :sys.get_state()
    |> elem(0)
  end
end
