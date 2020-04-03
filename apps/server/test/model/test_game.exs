defmodule Server.GameTest do
  use ExUnit.Case

  alias Server.User
  alias Server.Game

  @username1 TestUtil.random_username()
  @username2 TestUtil.random_username()

  setup_all do
    assert %User{username: @username1, password: ""} |> DB.Repo.insert() |> elem(0) == :ok
    assert %User{username: @username2, password: ""} |> DB.Repo.insert() |> elem(0) == :ok

    assert %Game{user1: first_user(), user2: second_user()} |> DB.Repo.insert() |> elem(0) == :ok

    on_exit(&teardown_all/0)
  end

  def teardown_all do
    %Server.Game{user1: first_user(), user2: second_user()} |> DB.Repo.delete()

    %Server.User{username: @username1} |> DB.Repo.delete()
    %Server.User{username: @username2} |> DB.Repo.delete()
  end

  test "check if game exists when first user is non-existent" do
    assert false == Game.exists?(TestUtil.random_username(), @username2)
  end

  test "check if game exists when second user is non-existent" do
    assert false == Game.exists?(@username1, TestUtil.random_username())
  end

  test "check if game between non-existent users exists" do
    assert false == Game.exists?(TestUtil.random_username(), TestUtil.random_username())
  end

  test "check if non-existent game exists" do
    user3 = TestUtil.random_username()
    assert true == User.insert(user3, "password")

    assert false == Game.exists?(user3, @username1)

    on_exit(fn -> %Server.User{username: user3} |> DB.Repo.delete() end)
  end

  test "check if existent game exists" do
    assert true == Game.exists?(@username1, @username2)
  end

  test "check if existent game exists but users are swapped" do
    assert true == Game.exists?(@username2, @username1)
  end

  test "q1 was added to the game" do
    %{question1: q1, question2: q2} = get_test_record()
    first_question = if first_user == @username1, do: q1, else: q2

    assert {:ok, first_question} == Game.get_question({@username1, @username2}, @username1)

  end

  test "q1 was added to the game but users are swapped" do
    %{question1: q1, question2: q2} = get_test_record()
    first_question = if first_user == @username1, do: q1, else: q2

    assert {:ok, first_question} == Game.get_question({@username2, @username1}, @username1)
  end

  test "q2 was added to the game" do
    %{question1: q1, question2: q2} = get_test_record()
    sec_question = if second_user == @username2, do: q2, else: q1

    assert {:ok, sec_question} == Game.get_question({@username1, @username2}, @username2)
  end

  test "q2 was added to the game but users are swapped" do
    %{question1: q1, question2: q2} = get_test_record()
    sec_question = if second_user == @username2, do: q2, else: q1

    assert {:ok, sec_question} == Game.get_question({@username2, @username1}, @username2)
  end

  test "s1 was added to the game" do
    %{score1: s1, score2: s2} = get_test_record()
    first_score = if first_user == @username1, do: s1, else: s2

    assert {:ok, s1} == Game.get_score({@username1, @username2}, @username1)
  end

  test "s1 was added to the game but users are swapped" do
    %{score1: s1, score2: s2} = get_test_record()
    first_score = if first_user == @username1, do: s1, else: s2

    assert {:ok, s1} == Game.get_score({@username2, @username1}, @username1)
  end

  test "s2 was added to the game" do
    %{score1: s1, score2: s2} = get_test_record()
    sec_score = if second_user == @username2, do: s2, else: s1

    assert {:ok, s2} == Game.get_score({@username1, @username2}, @username2)
  end

  test "s2 was added to the game but users are swapped" do
    %{score1: s1, score2: s2} = get_test_record()
    sec_score = if second_user == @username2, do: s2, else: s1

    assert {:ok, s2} == Game.get_score({@username2, @username1}, @username2)
  end

  test "add game where first user is 'nil'" do
    assert false == Game.insert(nil, @username2)
  end

  test "add game where sec user is 'nil'" do
    assert false == Game.insert(@username1, nil)
  end

  test "add game where first user doesn't exist" do
    assert false == Game.insert(TestUtil.random_username(), @username2)
  end

  test "add game where second user doesn't exist" do
    assert false == Game.insert(@username1, TestUtil.random_username())
  end

  test "add game where users don't exist" do
    assert false == Game.insert(TestUtil.random_username(), TestUtil.random_username())
  end

  test "add new game" do
    user3 = TestUtil.random_username()
    first = if user3 < @username1, do: user3, else: @username1
    second = if user3 >= @username1, do: user3, else: @username1

    assert true == User.insert(user3, "password")
    assert true == Game.insert(first, second)

    on_exit(fn -> teardown(user3, {first, second}) end)
  end

  test "add duplicate game" do
    assert false == Game.insert(@username1, @username2)
  end

  test "add duplicate game but users are swapped" do
    assert false == Game.insert(@username2, @username1)
  end

  test "add second game from the same user" do
    user3 = greater_username(@username1)
    assert true == User.insert(user3, "password")
    assert true == Game.insert(@username1, user3)

    on_exit(fn -> teardown(user3, {@username1, user3}) end)
  end

  test "add second game to the same user" do
    user3 = lesser_username(@username2)
    assert true == User.insert(user3, "password")
    assert true == Game.insert(user3, @username2)

    on_exit(fn -> teardown(user3, {user3, @username2}) end)
  end

  def teardown(user_to_del, _game_to_del = {user1, user2}) do
    %Game{user1: user1, user2: user2} |> DB.Repo.delete()
    %Server.User{username: user_to_del} |> DB.Repo.delete()
  end

  defp first_user when @username1 < @username2, do: @username1
  defp first_user, do: @username2

  defp second_user when @username1 > @username2, do: @username1
  defp second_user, do: @username2

  defp lesser_username(username) do
    num = Integer.parse(username) |> elem(0)

    "#{num - 1}"
  end

  defp greater_username(username) do
    num = Integer.parse(username) |> elem(0)

    "#{num + 1}"
  end

  defp get_test_record do
    DB.Repo.get_by(Game, %{user1: first_user(), user2: second_user()})
  end
end
