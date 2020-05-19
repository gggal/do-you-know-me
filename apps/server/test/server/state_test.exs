defmodule Server.WorkerTest do
  use ExUnit.Case

  alias Server.State

  test "state is empty upon creation" do
    state = State.new()
    assert %{} == state.users
    assert %{} == state.clients
  end

  test "add pair for existent user" do
    state = %State{users: %{"user" => [:client1]}, clients: %{client1: "user"}}
    state = State.add(state, "user", :client2)
    assert %{"user" => [:client1, :client2]} == state.users
    assert %{client1: "user", client2: "user"} == state.clients
  end

  test "add pair for new user" do
    state = %State{users: %{}, clients: %{}}
    state = State.add(state, "user", :client)
    assert %{"user" => [:client]} == state.users
    assert %{client: "user"} == state.clients
  end

  test "delete non-existent user" do
    state = %State{users: %{"user" => [:client1]}, clients: %{client1: "user"}}
    assert state == State.delete(state, "non_existent_user")
  end

  test "delete user successfully" do
    state = %State{users: %{"user" => [:client1]}, clients: %{client1: "user"}}
    state = State.delete(state, "user")
    assert %{} == state.users
    assert %{} == state.clients
  end

  test "delete non-existent client" do
    state = %State{users: %{"user" => [:client1]}, clients: %{client1: "user"}}
    assert state == State.delete_client(state, :client2)
  end

  test "delete last client for user" do
    state = %State{users: %{"user" => [:client1]}, clients: %{client1: "user"}}
    state = State.delete_client(state, :client1)
    assert %{} == state.users
    assert %{} == state.clients
  end

  test "delete non-last client for user" do
    state = %State{
      users: %{"user" => [:client1, :client2]},
      clients: %{client1: "user", client2: "user"}
    }

    state = State.delete_client(state, :client1)
    assert %{"user" => [:client2]} == state.users
    assert %{client2: "user"} == state.clients
  end

  test "check if state contains non-existent user" do
    state = %State{users: %{"user" => [:client1]}, clients: %{client1: "user"}}
    assert false == State.contains_user?(state, "non_existent_user")
  end

  test "check if state contains existent user" do
    state = %State{users: %{"user" => [:client1]}, clients: %{client1: "user"}}
    assert true == State.contains_user?(state, "user")
  end

  test "check if state contains non-existent client" do
    state = %State{users: %{"user" => [:client1]}, clients: %{client1: "user"}}
    assert false == State.contains_client?(state, :non_existent_client)
  end

  test "check if state contains existent client" do
    state = %State{users: %{"user" => [:client1]}, clients: %{client1: "user"}}
    assert true == State.contains_client?(state, :client1)
  end

  test "get clients for non-existent user" do
    state = %State{users: %{"user" => [:client1]}, clients: %{client1: "user"}}
    assert [] == State.get_clients(state, "non_existent_user")
  end

  test "get clients for existent user" do
    state = %State{users: %{"user" => [:client1]}, clients: %{client1: "user"}}
    assert [:client1] == State.get_clients(state, "user")
  end

  test "get user for existent client" do
    state = %State{users: %{"user" => [:client1]}, clients: %{client1: "user"}}
    assert "user" == State.get_user(state, :client1)
  end

  test "get user for non-existent client" do
    state = %State{users: %{"user" => [:client1]}, clients: %{client1: "user"}}
    assert nil == State.get_user(state, :client2)
  end
end
