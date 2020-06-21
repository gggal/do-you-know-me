defmodule Client.StateTest do
  use ExUnit.Case

  alias Client.State

  test "initial state contains no username" do
    assert nil == State.new().username
  end

  test "initial state contains empty to_answer map" do
    assert %{} == State.new().to_answer
  end

  test "initial state contains empty to_guess map" do
    assert %{} == State.new().to_guess
  end

  test "initial state contains empty to_see map" do
    assert %{} == State.new().to_see
  end

  test "initial state contains empty invitations map" do
    assert 0 == State.new().invitations |> MapSet.size()
  end

  test "get username successfully" do
    state = State.new()
    assert "user" == %{state | username: "user"} |> State.get_username()
  end

  test "set username successfully" do
    %State{username: user} = State.new() |> State.set_username("user")
    assert user == "user"
  end

  test "adding the same invitation twice should be ignored" do
    %{invitations: users} =
      State.new()
      |> State.add_invitation("user1")
      |> State.add_invitation("user2")
      |> State.add_invitation("user2")

    assert ["user1", "user2"] == MapSet.to_list(users)
  end

  test "removing non-existent invitation should be ignored" do
    %{invitations: users} =
      State.new()
      |> State.add_invitation("user1")
      |> State.add_invitation("user2")
      |> State.remove_invitation("user3")

    assert ["user1", "user2"] == MapSet.to_list(users)
  end

  test "removing an invitation successfully" do
    %{invitations: users} =
      State.new()
      |> State.add_invitation("user1")
      |> State.add_invitation("user2")
      |> State.remove_invitation("user2")

    assert ["user1"] == MapSet.to_list(users)
  end

  test "get invitations successfully" do
    state =
      State.new()
      |> State.add_invitation("user1")
      |> State.add_invitation("user2")
      |> State.add_invitation("user3")

    assert ["user1", "user2", "user3"] ==
             State.get_invitations(state) |> MapSet.to_list()
  end

  test "get review question for non-existent user" do
    assert nil == State.new() |> State.get_to_see("user")
  end

  test "get review question successfully" do
    state = %{State.new() | to_see: %{user: :question}}

    assert :question == state |> State.get_to_see(:user)
  end

  test "get all review users" do
    state = %{State.new() | to_see: %{user1: :q1, user2: :q2}}

    assert [:user1, :user2] == state |> State.get_all_to_see()
  end

  test "putting review question for existing user should be ignored" do
    state = %{State.new() | to_see: %{user1: :q1}}

    %State{to_see: map} = State.put_to_see(state, :user1, :q1)
    assert [:user1] == Map.keys(map)
  end

  test "putting review question successfully" do
    %State{to_see: map} = State.new() |> State.put_to_see(:user1, :q1)
    assert [:user1] == Map.keys(map)
    assert [:q1] == Map.values(map)
  end

  test "removing review question for non-existing user should be ignored" do
    assert State.new() == State.remove_to_see(State.new(), :user1)
  end

  test "removing review question successfully" do
    state = State.new() |> State.put_to_see(:user1, :q1)
    assert State.new() == State.remove_to_see(state, :user1)
  end

  test "get guess question for non-existent user" do
    assert nil == State.new() |> State.get_to_guess("user")
  end

  test "get guess question successfully" do
    state = %{State.new() | to_guess: %{user: :question}}

    assert :question == state |> State.get_to_guess(:user)
  end

  test "get all guess users" do
    state = %{State.new() | to_guess: %{user1: :q1, user2: :q2}}

    assert [:user1, :user2] == state |> State.get_all_to_guess()
  end

  test "putting guess question for existing user should be ignored" do
    state = %{State.new() | to_guess: %{user1: :q1}}

    %State{to_guess: map} = State.put_to_guess(state, :user1, :q1)
    assert [:user1] == Map.keys(map)
  end

  test "putting guess question successfully" do
    %State{to_guess: map} = State.new() |> State.put_to_guess(:user1, :q1)
    assert [:user1] == Map.keys(map)
    assert [:q1] == Map.values(map)
  end

  test "removing guess question for non-existing user should be ignored" do
    assert State.new() == State.remove_to_guess(State.new(), :user1)
  end

  test "removing guess question successfully" do
    state = State.new() |> State.put_to_guess(:user1, :q1)
    assert State.new() == State.remove_to_guess(state, :user1)
  end

  test "get answer question for non-existent user" do
    assert nil == State.new() |> State.get_to_answer("user")
  end

  test "get answer question successfully" do
    state = %{State.new() | to_answer: %{user: :question}}

    assert :question == state |> State.get_to_answer(:user)
  end

  test "get all answer users" do
    state = %{State.new() | to_answer: %{user1: :q1, user2: :q2}}

    assert [:user1, :user2] == state |> State.get_all_to_answer()
  end

  test "putting answer question for existing user should be ignored" do
    state = %{State.new() | to_answer: %{user1: :q1}}

    %State{to_answer: map} = State.put_to_answer(state, :user1, :q1)
    assert [:user1] == Map.keys(map)
  end

  test "putting answer question successfully" do
    %State{to_answer: map} = State.new() |> State.put_to_answer(:user1, :q1)
    assert [:user1] == Map.keys(map)
    assert [:q1] == Map.values(map)
  end

  test "removing answer question for non-existing user should be ignored" do
    assert State.new() == State.remove_to_answer(State.new(), :user1)
  end

  test "removing answer question successfully" do
    state = State.new() |> State.put_to_answer(:user1, :q1)
    assert State.new() == State.remove_to_answer(state, :user1)
  end

  test "listing empty list when no related users" do
    assert [] == State.new() |> State.all_related()
  end

  test "listing related users successfully" do
    state = %{
      State.new()
      | to_answer: %{user1: :q1},
        to_guess: %{user2: :q2},
        to_see: %{user3: :q3}
    }

    assert MapSet.new([:user1, :user2, :user3]) == state |> State.all_related() |> MapSet.new()
  end
end
