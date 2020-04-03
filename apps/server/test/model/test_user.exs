defmodule Server.UserTest do
  use ExUnit.Case

  alias Server.User

  @username TestUtil.random_username()

  setup_all do
    assert %Server.User{username: @username, password: ""} |> DB.Repo.insert() |> elem(0) == :ok

    on_exit(fn -> %Server.User{username: @username} |> DB.Repo.delete() end)
  end

  test "check if a non-existent user exists" do
    assert false == User.exists?(TestUtil.random_username())
  end

  test "check if an existent user exists" do
    assert true == User.exists?(@username)
  end

  test "insert user with nil username" do
    assert false == User.insert(nil, "password")
  end

  test "insert user with nil password" do
    assert false == User.insert(TestUtil.random_username(), nil)
  end

  test "insert user with empty username" do
    assert false == User.insert("", "password")
  end

  test "insert user with empty password" do
    assert false == User.insert(TestUtil.random_username(), "")
  end

  test "insert user with duplicate username" do
    assert false == User.insert(@username, "password")
  end

  test "insert user with invalid format username" do
    assert false == User.insert("?", "password")
  end

  test "insert valid user" do
    to_insert = TestUtil.random_username()
    assert true == User.insert(to_insert, "password")

    on_exit(fn -> %Server.User{username: to_insert} |> DB.Repo.delete() end)
  end
end
