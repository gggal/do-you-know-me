defmodule CLI.StateTest do
  use ExUnit.Case

  alias CLI.State

  test "new state is empty" do
    assert %State{invites: MapSet.new()} == State.new()
  end

  test "get all invites when state is empty" do
    assert [] == State.new() |> State.get_invites()
  end

  test "get all invites when state is not empty" do
    state = %State{invites: MapSet.new(["user1", "user2"])}
    assert ["user1", "user2"] == state |> State.get_invites()
  end

  test "get all invites for duplicate invites" do
    assert ["user"] ==
             State.new()
             |> State.add_invite("user")
             |> State.add_invite("user")
             |> State.get_invites()
  end

  test "add invite successfully" do
    %State{invites: test_invite} = State.new() |> State.add_invite("user")
    assert test_invite == MapSet.new(["user"])
  end

  test "try to add non-string invite" do
    catch_error(State.add_invite(State.new(), 123))
  end

  test "delete invites successfully" do
    state = %State{invites: MapSet.new(["user1", "user2", "user3"])}
    assert %State{invites: MapSet.new()} == State.delete_invites(state)
  end
end
