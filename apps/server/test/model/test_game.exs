defmodule Server.GameTest do
  use ExUnit.Case

  alias Server.User
  alias Server.Game
  alias Server.Invitation
  alias Server.Question
  alias Server.Score

  @username1 TestUtil.random_username()
  @username2 TestUtil.random_username()

  setup_all do
    assert %User{username: @username1, password: ""} |> DB.Repo.insert() |> elem(0) == :ok
    assert %User{username: @username2, password: ""} |> DB.Repo.insert() |> elem(0) == :ok

    {:ok, %{id: q_id1}} = %Question{question_num: 1, answer: "a", guess: "b"} |> DB.Repo.insert()
    {:ok, %{id: q_id2}} = %Question{question_num: 2, answer: "a", guess: "b"} |> DB.Repo.insert()

    {:ok, %{id: s_id1}} = %Score{} |> DB.Repo.insert()
    {:ok, %{id: s_id2}} = %Score{} |> DB.Repo.insert()

    assert %Game{
             user1: first_user(),
             user2: second_user(),
             question1: q_id1,
             question2: q_id2,
             score1: s_id1,
             score2: s_id2
           }
           |> DB.Repo.insert()
           |> elem(0) == :ok

    on_exit(&teardown_all/0)
  end

  def teardown_all do
    %{question1: q_id1, question2: q_id2, score1: s_id1, score2: s_id2} =
      game = Game |> DB.Repo.get_by(%{user1: first_user(), user2: second_user()})

    DB.Repo.delete(game)

    %User{username: @username1} |> DB.Repo.delete()
    %User{username: @username2} |> DB.Repo.delete()

    %Question{id: q_id1} |> DB.Repo.delete()
    %Question{id: q_id2} |> DB.Repo.delete()

    %Score{id: s_id1} |> DB.Repo.delete()
    %Score{id: s_id2} |> DB.Repo.delete()
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
    first_question = if first_user() == @username1, do: q1, else: q2

    assert {:ok, first_question} == Game.get_question({@username1, @username2}, @username1)
  end

  test "q1 was added to the game but users are swapped" do
    %{question1: q1, question2: q2} = get_test_record()
    first_question = if first_user() == @username1, do: q1, else: q2

    assert {:ok, first_question} == Game.get_question({@username2, @username1}, @username1)
  end

  test "q2 was added to the game" do
    %{question1: q1, question2: q2} = get_test_record()
    sec_question = if second_user() == @username2, do: q2, else: q1

    assert {:ok, sec_question} == Game.get_question({@username1, @username2}, @username2)
  end

  test "q2 was added to the game but users are swapped" do
    %{question1: q1, question2: q2} = get_test_record()
    sec_question = if second_user() == @username2, do: q2, else: q1

    assert {:ok, sec_question} == Game.get_question({@username2, @username1}, @username2)
  end

  test "try to obtain question but user1 is nil" do
    assert :err == Game.get_question({nil, @username1}, @username1)
  end

  test "try to obtain question but user1 is invalid" do
    assert :err ==
             Game.get_question({TestUtil.random_username(), @username1}, @username1)
  end

  test "try to obtain question but user2 is nil" do
    assert :err ==
             Game.get_question({@username1, nil}, @username1)
  end

  test "try to obtain question but user2 is invalid" do
    assert :err ==
             Game.get_question({@username1, TestUtil.random_username()}, @username1)
  end

  test "try to obtain question but 'for' user is nil" do
    assert :err ==
             Game.get_question({@username1, @username2}, nil)
  end

  test "try to obtain question but 'for' user is invalid" do
    assert :err ==
             Game.get_question({@username1, @username2}, TestUtil.random_username())
  end

  test "obtain question id when users are swapped" do
    %{question1: q1, question2: q2} = get_test_record()

    assert {:ok, q1} ==
             Game.get_question({second_user(), first_user()}, first_user())

    assert {:ok, q2} ==
             Game.get_question({second_user(), first_user()}, second_user())
  end

  test "obtain question id successfully" do
    %{question1: q1, question2: q2} = get_test_record()

    assert {:ok, q1} ==
             Game.get_question({first_user(), second_user()}, first_user())

    assert {:ok, q2} ==
             Game.get_question({first_user(), second_user()}, second_user())
  end

  test "try to obtain score but user1 is nil" do
    assert :err == Game.get_score({nil, @username1}, @username1)
  end

  test "try to obtain score but user1 is invalid" do
    assert :err ==
             Game.get_score({TestUtil.random_username(), @username1}, @username1)
  end

  test "try to obtain score but user2 is nil" do
    assert :err ==
             Game.get_score({@username1, nil}, @username1)
  end

  test "try to obtain score but user2 is invalid" do
    assert :err ==
             Game.get_score({@username1, TestUtil.random_username()}, @username1)
  end

  test "try to obtain score but 'for' user is nil" do
    assert :err ==
             Game.get_score({@username1, @username2}, nil)
  end

  test "try to obtain score but 'for' user is invalid" do
    assert :err ==
             Game.get_score({@username1, @username2}, TestUtil.random_username())
  end

  test "obtain score id when users are swapped" do
    %{score1: s1, score2: s2} = get_test_record()

    assert {:ok, s1} ==
             Game.get_score({second_user(), first_user()}, first_user())

    assert {:ok, s2} ==
             Game.get_score({second_user(), first_user()}, second_user())
  end

  test "obtain score id successfully" do
    %{score1: s1, score2: s2} = get_test_record()

    assert {:ok, s1} ==
             Game.get_score({first_user(), second_user()}, first_user())

    assert {:ok, s2} ==
             Game.get_score({first_user(), second_user()}, second_user())
  end

  test "s1 was added to the game" do
    %{score1: s1, score2: s2} = get_test_record()
    first_score = if first_user() == @username1, do: s1, else: s2

    assert {:ok, first_score} == Game.get_score({@username1, @username2}, @username1)
  end

  test "s1 was added to the game but users are swapped" do
    %{score1: s1, score2: s2} = get_test_record()
    first_score = if first_user() == @username1, do: s1, else: s2

    assert {:ok, first_score} == Game.get_score({@username2, @username1}, @username1)
  end

  test "s2 was added to the game" do
    %{score1: s1, score2: s2} = get_test_record()
    sec_score = if second_user() == @username2, do: s2, else: s1

    assert {:ok, sec_score} == Game.get_score({@username1, @username2}, @username2)
  end

  test "s2 was added to the game but users are swapped" do
    %{score1: s1, score2: s2} = get_test_record()
    sec_score = if second_user() == @username2, do: s2, else: s1

    assert {:ok, sec_score} == Game.get_score({@username2, @username1}, @username2)
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

    on_exit(fn -> teardown_user_and_game(user3, {first, second}) end)
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

    on_exit(fn -> teardown_user_and_game(user3, {@username1, user3}) end)
  end

  test "add second game to the same user" do
    user3 = lesser_username(@username2)
    assert true == User.insert(user3, "password")
    assert true == Game.insert(user3, @username2)

    on_exit(fn -> teardown_user_and_game(user3, {user3, @username2}) end)
  end

  test "no related users for unknown user" do
    assert [] == Game.all_related(TestUtil.random_username())
  end

  test "list related user for valid user 1" do
    # create user, insert user, start game
    user2 = lesser_username(@username1)
    assert true == User.insert(user2, "password")
    assert true == Game.insert(user2, @username1)
    assert user2 in Game.all_related(@username1)

    on_exit(fn -> teardown_user_and_game(user2, {user2, @username1}) end)
  end

  test "list related user for valid user 2" do
    # create user, insert user, start game
    user2 = greater_username(@username1)
    assert true == User.insert(user2, "password")
    assert true == Game.insert(user2, @username1)
    assert user2 in Game.all_related(@username1)

    on_exit(fn -> teardown_user_and_game(user2, {@username1, user2}) end)
  end

  test "the user themselves is not in the related list" do
    assert @username1 not in Game.all_related(@username1)
  end

  test "starting game inserts new record in game table" do
    user3 = lesser_username(@username1)
    first = if user3 < @username1, do: user3, else: @username1
    second = if user3 >= @username1, do: user3, else: @username1
    assert true == User.insert(user3, "password")
    assert true == Invitation.insert(first, second)

    assert true == Game.start(first, second)
    assert true == Game.exists?(@username1, user3)

    on_exit(fn -> teardown_user_and_game(user3, {first, second}) end)
  end

  test "starting game adds question numbers" do
    user3 = lesser_username(@username1)
    first = if user3 < @username1, do: user3, else: @username1
    second = if user3 >= @username1, do: user3, else: @username1
    assert true == User.insert(user3, "password")
    assert true == Invitation.insert(first, second)

    assert true == Game.start(first, second)

    assert nil !=
             Game.get_question({@username1, user3}, @username1)
             |> elem(1)
             |> Question.get_question_number()

    assert nil !=
             Game.get_question({@username1, user3}, user3)
             |> elem(1)
             |> Question.get_question_number()

    on_exit(fn -> teardown_user_and_game(user3, {first, second}) end)
  end

  test "starting game inserts game for swapped users" do
    user3 = lesser_username(@username1)
    first = if user3 < @username1, do: user3, else: @username1
    second = if user3 >= @username1, do: user3, else: @username1
    assert true == User.insert(user3, "password")
    assert true == Invitation.insert(second, first)

    assert true == Game.start(second, first)
    assert true == Game.exists?(@username1, user3)

    on_exit(fn -> teardown_user_and_game(user3, {first, second}) end)
  end

  test "starting game deletes invitation" do
    user3 = lesser_username(@username1)
    first = if user3 < @username1, do: user3, else: @username1
    second = if user3 >= @username1, do: user3, else: @username1
    assert true == User.insert(user3, "password")
    assert true == Invitation.insert(first, second)

    assert true == Game.start(first, second)
    assert false == Invitation.exists?(@username1, user3)

    on_exit(fn -> teardown_user_and_game(user3, {first, second}) end)
  end

  test "rollback when starting game fails due to missing invitation" do
    user3 = lesser_username(@username1)
    first = if user3 < @username1, do: user3, else: @username1
    second = if user3 >= @username1, do: user3, else: @username1
    assert true == User.insert(first, "password")

    assert false == Game.start(first, second)
    assert false == Game.exists?(first, second)

    on_exit(fn -> %User{username: user3} |> DB.Repo.delete() end)
  end

  test "rollback when starting game fails due to game already existing" do
    assert true == Invitation.insert(@username1, @username2)

    assert false == Game.start(@username1, @username2)

    on_exit(fn -> Invitation.delete(@username1, @username2) end)
  end

  test "try answering question but there's no such game" do
    user3 = TestUtil.random_username()
    assert true == User.insert(user3, "password")

    assert false == Game.answer_question({@username1, user3}, @username1, "a")

    on_exit(fn -> %User{username: user3} |> DB.Repo.delete() end)
  end

  test "try answering question but there's no such user1" do
    assert false ==
             Game.answer_question({TestUtil.random_username(), @username1}, @username1, "a")
  end

  test "try answering question but there's no such user2" do
    assert false ==
             Game.answer_question({@username1, TestUtil.random_username()}, @username1, "a")
  end

  test "try answering question but first user is nil" do
    assert false ==
             Game.answer_question({nil, @username1}, @username1, "a")
  end

  test "try answering question but sec user is nil" do
    assert false ==
             Game.answer_question({@username1, nil}, @username1, "a")
  end

  test "try answering question but 'from' user is nil" do
    assert false ==
             Game.answer_question({@username1, @username2}, nil, "a")
  end

  test "try answering question but 'from' user is not user1 or user2" do
    assert false ==
             Game.answer_question({@username1, @username2}, TestUtil.random_username(), "a")
  end

  test "answering question but the answer is invalid" do
    assert false ==
             Game.answer_question({@username1, @username2}, @username2, "d")
  end

  test "answering question with nil answer" do
    assert true ==
             Game.answer_question({@username1, @username2}, @username1, nil)
  end

  test "rollback answering question when setting answer fails" do
    q_number =
      Game.get_question({@username1, @username2}, @username1)
      |> elem(1)
      |> Question.get_question_number()

    assert false ==
             Game.answer_question({@username1, @username2}, nil, nil)

    assert q_number ==
             Game.get_question({@username1, @username2}, @username1)
             |> elem(1)
             |> Question.get_question_number()
  end

  test "question number changes when answering question successfully" do
    q_number =
      Game.get_question({@username1, @username2}, @username1)
      |> elem(1)
      |> Question.get_question_number()

    assert true ==
             Game.answer_question({@username1, @username2}, @username1, "a")

    assert q_number !=
             Game.get_question({@username1, @username2}, @username1)
             |> elem(1)
             |> Question.get_question_number()
  end

  test "answer changes when answering question successfully" do
    assert true ==
             Game.answer_question({@username1, @username2}, @username1, "b")

    assert {:ok, "b"} ==
             Game.get_question({@username1, @username2}, @username1)
             |> elem(1)
             |> Question.get_question_answer()
  end

  test "guess is nil when answering question successfully" do
    assert true ==
             Game.answer_question({@username1, @username2}, @username1, "b")

    assert {:ok, nil} ==
             Game.get_question({@username1, @username2}, @username1)
             |> elem(1)
             |> Question.get_question_guess()
  end

  def teardown(user_to_del, _game_to_del = {user1, user2}) do
    %Game{user1: user1, user2: user2} |> DB.Repo.delete()
    %User{username: user_to_del} |> DB.Repo.delete()
  end

  def teardown_user_and_game(user_to_del, {user1, user2}) do
    if Invitation |> DB.Repo.get_by(%{from: user1, to: user2}) do
      %Invitation{from: user1, to: user2} |> DB.Repo.delete()
    end

    %{question1: q_id1, question2: q_id2, score1: s_id1, score2: s_id2} =
      game = DB.Repo.get_by(Game, %{user1: user1, user2: user2})

    DB.Repo.delete(game)

    if q_id1, do: %Question{id: q_id1} |> DB.Repo.delete()
    if q_id2, do: %Question{id: q_id2} |> DB.Repo.delete()

    if s_id1, do: %Score{id: s_id1} |> DB.Repo.delete()
    if s_id2, do: %Score{id: s_id2} |> DB.Repo.delete()

    %User{username: user_to_del} |> DB.Repo.delete()
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
