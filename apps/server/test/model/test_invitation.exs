defmodule Server.InvitationTest do
  use ExUnit.Case

  alias Server.User
  alias Server.Invitation

  @username1 TestUtil.random_username()
  @username2 TestUtil.random_username()

  setup_all do
    assert %User{username: @username1, password: ""} |> DB.Repo.insert() |> elem(0) == :ok
    assert %User{username: @username2, password: ""} |> DB.Repo.insert() |> elem(0) == :ok
    assert %Invitation{from: @username1, to: @username2} |> DB.Repo.insert() |> elem(0) == :ok

    on_exit(&teardown_all/0)
  end

  def teardown_all do
    # Server.Invitation |> DB.Repo.get_by(%{from: @username1, to: @username2}) |> DB.Repo.delete()
    %Server.Invitation{from: @username1, to: @username2}
    |> DB.Repo.delete(stale_error_field: :from)

    %Server.User{username: @username1} |> DB.Repo.delete()
    %Server.User{username: @username2} |> DB.Repo.delete()
  end

  test "check if invitation from non-existent user exists" do
    assert false == Invitation.exists?(TestUtil.random_username(), @username2)
  end

  test "check if invitation to non-existent user exists" do
    assert false == Invitation.exists?(@username1, TestUtil.random_username())
  end

  test "check if invitation from and to non-existent users exists" do
    assert false == Invitation.exists?(TestUtil.random_username(), TestUtil.random_username())
  end

  test "check if non-existent invitation exists" do
    assert false == Invitation.exists?(@username2, @username1)
  end

  test "check if existent invitation exists" do
    assert true == Invitation.exists?(@username1, @username2)
  end

  test "add invitation from 'nil' user" do
    assert false == Invitation.insert(nil, @username2)
  end

  test "add invitation to 'nil' user" do
    assert false == Invitation.insert(@username1, nil)
  end

  test "add invitation from non-existent user" do
    assert false == Invitation.insert(TestUtil.random_username(), @username2)
  end

  test "add invitation to non-existent user" do
    assert false == Invitation.insert(@username1, TestUtil.random_username())
  end

  test "add invitation from and to non-existent users" do
    assert false == Invitation.insert(TestUtil.random_username(), TestUtil.random_username())
  end

  test "add new invitation" do
    assert true == Invitation.insert(@username2, @username1)
    nil
    on_exit(fn -> %Invitation{from: @username2, to: @username1} |> DB.Repo.delete() end)
  end

  test "add duplicate invitation" do
    assert false == Invitation.insert(@username1, @username2)
  end

  test "add second invitation from the same user" do
    user3 = TestUtil.random_username()
    assert true == User.insert(user3, "password")
    assert true == Invitation.insert(@username1, user3)

    on_exit(fn ->
      %Invitation{from: @username1, to: user3} |> DB.Repo.delete()
      %Server.User{username: user3} |> DB.Repo.delete()
    end)
  end

  test "add second invitation to the same user" do
    user3 = TestUtil.random_username()
    assert true == User.insert(user3, "password")
    assert true == Invitation.insert(user3, @username2)

    on_exit(fn ->
      %Invitation{from: user3, to: @username2} |> DB.Repo.delete()
      %Server.User{username: user3} |> DB.Repo.delete()
    end)
  end

  test "delete non-existent reservation" do
    assert false == Invitation.delete(@username2, @username1)
  end

  test "delete existent reservation" do
    assert true == Invitation.delete(@username1, @username2)

    on_exit(fn -> assert %Invitation{from: @username1, to: @username2} |> DB.Repo.insert() end)
  end
end
