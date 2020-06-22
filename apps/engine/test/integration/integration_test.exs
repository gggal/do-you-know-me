# Client guess question sets the correct inner state
# Client guess question sets the correct inner state for other user
# Client guess question changes the db

defmodule IntegrationTest do
  use ExUnit.Case

  alias Client.Worker, as: Client
  alias Server.User
  alias Server.Game
  alias Server.Invitation
  alias Server.Question
  alias Server.Score

  def node1(), do: :"node1@127.0.0.1"
  def node2(), do: :"node2@127.0.0.1"
  def node3(), do: :"node3@127.0.0.1"

  setup do
    remote_client(node1(), :unregister, ["pass"])
    remote_client(node2(), :unregister, ["pass"])
    remote_client(node2(), :unregister, ["pass"])

    :ok
  end

  setup_all do
    on_exit(&wipe_out_db/0)
    # :ok
  end

  test "registering/unregistering" do
    username = TestUtil.random_username()

    # registering a client adds a user to the database
    assert :ok == :rpc.call(node1(), Client, :register, [username, "pass"])
    assert true == User.exists?(username)
    # unregistering a client removes the user from the database
    assert :ok == :rpc.call(node1(), Client, :unregister, ["pass"])
    assert false == User.exists?(username)
  end

  test "login" do
    user1 = TestUtil.random_username()

    # preparing database
    assert true == User.insert(user1, "pass")
    assert true == User.insert("user2", "pass")
    assert true == User.insert("user3", "pass")
    assert true == Invitation.insert("user3", user1)
    {:ok, %{id: q_id1}} = %Question{question_num: 1, answer: nil, guess: nil} |> DB.Repo.insert()
    {:ok, %{id: q_id2}} = %Question{question_num: 2, answer: nil, guess: nil} |> DB.Repo.insert()

    {:ok, %{id: old_q_id1}} =
      %Question{question_num: 3, answer: "a", guess: "c"} |> DB.Repo.insert()

    {:ok, %{id: old_q_id2}} =
      %Question{question_num: 4, answer: "a", guess: nil} |> DB.Repo.insert()

    {:ok, %{id: s_id1}} = %Score{} |> DB.Repo.insert()
    {:ok, %{id: s_id2}} = %Score{} |> DB.Repo.insert()

    assert %Game{
             user1: user1,
             user2: "user2",
             question1: q_id1,
             question2: q_id2,
             old_question1: old_q_id1,
             old_question2: old_q_id2,
             score1: s_id1,
             score2: s_id2,
             turn: false
           }
           |> DB.Repo.insert()
           |> elem(0) == :ok

    # login successfully
    assert :ok == remote_client(node1(), :login, [user1, "pass"])

    # internal state is set correctly
    assert {:ok, MapSet.new(["user3"])} ==
             remote_client(node1(), :get_invitations, [])

    assert {:ok, fetch_question(1)} ==
             remote_client(node1(), :get_to_answer, ["user2"])

    assert {:ok, {fetch_question(4), "a"}} ==
             remote_client(node1(), :get_to_guess, ["user2"])

    assert {:ok, {fetch_question(3), "a", "c"}} ==
             remote_client(node1(), :get_to_see, ["user2"])
  end

  test "invite" do
    user1 = TestUtil.random_username()
    user2 = TestUtil.random_username()

    assert :ok == remote_client(node1(), :register, [user1, "pass"])
    assert :ok == remote_client(node2(), :register, [user2, "pass"])

    assert :ok == remote_client(node1(), :invite, [user2])
    assert true == Invitation.exists?(user1, user2)
    assert {:ok, MapSet.new([user1])} == remote_client(node2(), :get_invitations, [])
    assert :ok == remote_client(node2(), :decline, [user1])
    assert false == Invitation.exists?(user1, user2)

    assert :ok == remote_client(node2(), :invite, [user1])
    assert true == Invitation.exists?(user2, user1)
    assert {:ok, MapSet.new([user2])} == remote_client(node1(), :get_invitations, [])
    assert :ok == remote_client(node1(), :accept, [user2])
    assert false == Invitation.exists?(user2, user1)
  end

  test "mutual invite" do
    user1 = TestUtil.random_username()
    user2 = TestUtil.random_username()

    assert :ok == remote_client(node1(), :register, [user1, "pass"])
    assert :ok == remote_client(node2(), :register, [user2, "pass"])

    assert :ok == remote_client(node1(), :invite, [user2])
    assert :ok == remote_client(node2(), :invite, [user1])
    assert false == Invitation.exists?(user1, user2)
    assert false == Invitation.exists?(user2, user1)
    assert {:ok, MapSet.new()} == remote_client(node1(), :get_invitations, [])
    assert {:ok, MapSet.new()} == remote_client(node2(), :get_invitations, [])
    assert true == Game.exists?(user1, user2)
  end

  test "get turn" do
    user1 = "a"
    user2 = "b"
    user3 = "c"

    assert :ok == remote_client(node1(), :register, [user1, "pass"])
    assert :ok == remote_client(node2(), :register, [user2, "pass"])
    assert :ok == remote_client(node3(), :register, [user3, "pass"])
    # start game
    assert :ok == remote_client(node1(), :invite, [user2])
    assert :ok == remote_client(node2(), :accept, [user1])
    # turn field is true when it's second user's turn
    %{turn: true} = DB.Repo.get_by(Game, %{user1: user1, user2: user2})
    # orm function returns the correct result
    assert {:ok, user2} == Game.get_turn(user2, user1)
    # clients api returns the correct result
    assert {:ok, false} == remote_client(node1(), :get_turn, [user2])
    assert {:ok, true} == remote_client(node2(), :get_turn, [user1])

    # same as above but it's the first user who starts first
    assert :ok == remote_client(node3(), :invite, [user2])
    assert :ok == remote_client(node2(), :accept, [user3])
    %{turn: false} = DB.Repo.get_by(Game, %{user1: user2, user2: user3})
    assert {:ok, user2} == Game.get_turn(user3, user2)
    assert {:ok, false} == remote_client(node3(), :get_turn, [user2])
    assert {:ok, true} == remote_client(node2(), :get_turn, [user3])
  end

  test "answer/guess game workflow" do
    user1 = TestUtil.random_username()
    user2 = TestUtil.random_username()

    assert :ok == remote_client(node1(), :register, [user1, "pass"])
    assert :ok == remote_client(node2(), :register, [user2, "pass"])

    assert :ok == remote_client(node1(), :invite, [user2])
    assert :ok == remote_client(node2(), :accept, [user1])

    assert true == Game.exists?(user1, user2)
    # state is set after the game has started
    {:ok, q1} = Game.get_question({user1, user2}, user1)
    {:ok, q2} = Game.get_question({user1, user2}, user2)
    {:ok, q_num1} = Question.get_question_number(q1)
    {:ok, q_num2} = Question.get_question_number(q2)
    assert {:ok, fetch_question(q_num1)} == remote_client(node1(), :get_to_answer, [user2])
    assert {:ok, fetch_question(q_num2)} == remote_client(node2(), :get_to_answer, [user1])
    assert {:err, :no_such_question} == remote_client(node1(), :get_to_guess, [user2])
    assert {:err, :no_such_question} == remote_client(node2(), :get_to_guess, [user1])
    assert {:err, :no_such_question} == remote_client(node1(), :get_to_see, [user2])
    assert {:err, :no_such_question} == remote_client(node2(), :get_to_see, [user1])
    # Question is not eligible if it's not user's turn to play
    assert {:err, :not_turn} == remote_client(node1(), :give_answer, [user2, "a"])
    # Client answering the question sets the correct inner state
    assert :ok == remote_client(node2(), :give_answer, [user1, "a"])
    # Client answering the question swaps the questions
    assert {:ok, q2} == Game.get_old_question({user1, user2}, user2)
    {:ok, "a"} = Question.get_question_answer(q2)
    {:ok, nil} = Question.get_question_guess(q2)
    {:ok, new_q2} = Game.get_question({user1, user2}, user2)
    {:ok, new_q_num2} = Question.get_question_number(new_q2)
    assert new_q_num2 != nil
    {:ok, nil} = Question.get_question_answer(new_q2)
    {:ok, nil} = Question.get_question_guess(new_q2)
    assert {:ok, fetch_question(new_q_num2)} == remote_client(node2(), :get_to_answer, [user1])
    assert {:ok, {fetch_question(q_num2), "a"}} == remote_client(node1(), :get_to_guess, [user2])
    # Client answering the question changes the turn
    assert {:ok, false} == remote_client(node2(), :get_turn, [user1])
    assert {:ok, true} == remote_client(node1(), :get_turn, [user2])
    # Client guessing the question sets the correct inner state
    assert {:ok, false} == remote_client(node1(), :give_guess, [user2, "b"])
    {:ok, "b"} = Question.get_question_guess(q2)

    assert {:ok, {fetch_question(q_num2), "a", "b"}} ==
             remote_client(node2(), :get_to_see, [user1])

    # Go to the next level by answering a question on each side
    assert :ok == remote_client(node1(), :give_answer, [user2, "c"])
    assert :ok == remote_client(node2(), :give_answer, [user1, "c"])
    # Questions must be swapped once more
    assert {:ok, q2} == Game.get_question({user1, user2}, user2)
    assert {:ok, new_q2} == Game.get_old_question({user1, user2}, user2)
  end

  defp wipe_out_db do
    Server.Game |> DB.Repo.all() |> Enum.map(fn rec -> DB.Repo.delete(rec) end)
    Server.Invitation |> DB.Repo.all() |> Enum.map(fn rec -> DB.Repo.delete(rec) end)
    Server.User |> DB.Repo.all() |> Enum.map(fn rec -> DB.Repo.delete(rec) end)
    Server.Score |> DB.Repo.all() |> Enum.map(fn rec -> DB.Repo.delete(rec) end)
    Server.Question |> DB.Repo.all() |> Enum.map(fn rec -> DB.Repo.delete(rec) end)
  end

  defp remote_client(node, func, args) do
    :rpc.call(node, Client, func, args)
  end

  defp fetch_question(question_number) do
    {:ok, q} = Client.fetch_question(question_number)
    q
  end
end
