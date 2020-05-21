defmodule Server.WorkerTest do
  use ExUnit.Case
  # doctest First
  import Mox
  setup :verify_on_exit!
  setup :set_mox_global

  require Logger

  alias Server.State

  def node1(), do: :"node1@127.0.0.1"
  def node2(), do: :"node2@127.0.0.1"
  def node3(), do: :"node3@127.0.0.1"

  setup do
    # send dummy clients this pid, so they can redirect everything they're being sent
    # this requires synchronous test execution
    :ok = GenServer.call({:quiz_client, node1()}, :set_tester)
    :ok = GenServer.call({:quiz_client, node2()}, :set_tester)
    :ok = GenServer.call({:quiz_client, node3()}, :set_tester)

    # put the server in a consistent initial state
    :sys.replace_state(server_pid(), fn _state ->
      %State{
        users: %{"username2" => [:"node2@127.0.0.1"], "username3" => [:"node3@127.0.0.1"]},
        clients: %{"node2@127.0.0.1": "username2", "node3@127.0.0.1": "username3"}
      }
    end)

    on_exit(&teardown/0)
  end

  defp teardown do
    :sys.replace_state(server_pid(), fn _state -> State.new() end)
  end

  test "unsuccessful registration with empty username" do
    stub_register_user()

    assert :invalid_username == remote_call(node1(), {:register, "", "pass"})
  end

  test "unsuccessful registration with empty password" do
    stub_register_user()

    assert :invalid_password == remote_call(node1(), {:register, "username1", ""})
  end

  test "unsuccessful registration with ill-formatted username" do
    stub_register_user()

    assert :invalid_username == remote_call(node1(), {:register, "&@#", "password"})
  end

  test "unsuccessful registration for already registered client" do
    stub_register_user()

    assert :already_registered == remote_call(node2(), {:register, "username4", "password"})
  end

  test "unsuccessful registration for a client with already taken name" do
    stub_register_user()
    UserMock |> expect(:exists?, fn _name -> true end)

    assert :taken == remote_call(node1(), {:register, "username2", "password"})
  end

  test "unsuccessful registration due to failed insert query" do
    stub_register_user()
    expect(UserMock, :insert, fn _name, _ -> false end)

    assert :db_error == remote_call(node1(), {:register, "username1", "password"})
  end

  test "successfully registering a client" do
    stub_register_user()

    assert :ok == remote_call(node1(), {:register, "username1", "password"})
  end

  test "add user to online users list when registering" do
    assert "username2" == :sys.get_state(server_pid()) |> State.get_user(node2())
  end

  test "failing to unregister a non-registered client" do
    assert :unauthenticated == remote_call(node1(), {:unregister, "password"})
  end

  test "failing to unregister unauthenticated client" do
    stub_unregister_user()

    assert :unauthenticated == remote_call(node2(), {:unregister, "wrong_password"})
  end

  test "failing to unregister client when db fail occurs" do
    stub_unregister_user()

    UserMock |> expect(:delete, fn _name -> false end)
    assert :db_error == remote_call(node2(), {:unregister, "password"})
  end

  test "remove user from online users list when unregistering" do
    stub_unregister_user()

    assert :ok == remote_call(node2(), {:unregister, "password"})
  end

  test "successfully unregistering a client" do
    stub_unregister_user()

    assert :ok == remote_call(node2(), {:unregister, "password"})
  end

  test "unsuccessful login for already logged in client" do
    stub_login()

    assert :already_logged_in == remote_call(node2(), {:login, "username2", "password"})
  end

  test "unsuccessful login for unregistered user" do
    stub_login()
    UserMock |> expect(:exists?, fn _name -> false end)

    assert :wrong_credentials == remote_call(node1(), {:login, "username1", "password"})
  end

  test "unsuccessful login because of wrong password" do
    stub_login()

    assert :wrong_credentials == remote_call(node1(), {:login, "username1", "wrong_password"})
  end

  test "unsuccessful login because of empty string password" do
    stub_login()

    assert :wrong_credentials == remote_call(node1(), {:login, "username1", ""})
  end

  test "unsuccessful login because of nil password" do
    stub_login()

    assert :wrong_credentials == remote_call(node1(), {:login, "username1", nil})
  end

  test "successful login" do
    stub_login()

    assert :ok == remote_call(node1(), {:login, "username1", "password"})
  end

  test "invitations are sent after login" do
    stub_login()
    remote_call(node1(), {:login, "username1", "password"})

    assert :ok == received(node1(), :cast, {:add_invitation, "username2"})
  end

  test "questions for answering are sent after login" do
    stub_login()
    QuestionMock |> expect(:get_question_answer, 2, fn _ -> {:ok, nil} end)
    remote_call(node1(), {:login, "username1", "password"})

    assert :ok == received(node1(), :cast, {:add_question, "username3", 1})
  end

  test "questions for guessing are sent after login" do
    stub_login()
    QuestionMock |> expect(:get_question_guess, 2, fn _ -> {:ok, nil} end)
    remote_call(node1(), {:login, "username1", "password"})

    assert :ok == received(node1(), :cast, {:add_guess, "username3", 2, :a})
  end

  test "questions for review are sent after login" do
    stub_login()
    remote_call(node1(), {:login, "username1", "password"})

    assert :ok == received(node1(), :cast, {:add_see, "username3", 1, :a, :b})
  end

  test "successful login of a user from second client" do
    stub_login()

    assert :ok == remote_call(node1(), {:login, "username2", "password"})
  end

  test "add user to online users list when logging in" do
    stub_login()
    assert :ok = remote_call(node1(), {:login, "username1", "password"})
    assert "username1" == :sys.get_state(server_pid()) |> State.get_user(node1())
  end

  test "remove user from online users list when client is disconnecting" do
    send(server_pid(), {:DOWN, "a", :process, {"s", node2()}, "a"})
    Process.sleep(1_000)
    assert nil == :sys.get_state(server_pid()) |> State.get_user(node2())
  end

  test "disconnection of unknown client gets ignored" do
    initial_state = :sys.get_state(server_pid())
    send(server_pid(), {:DOWN, "a", :process, {"s", :invalid}, "a"})
    Process.sleep(1_000)
    assert initial_state == :sys.get_state(server_pid())
  end

  test "try listing users from not logged in client" do
    assert :unauthenticated == remote_call(node1(), :list_users)
  end

  test "list users successfully" do
    to_return = ["user1", "user2", "user3"]
    UserMock |> expect(:all, fn -> to_return end)
    assert {:ok, to_return} == remote_call(node2(), :list_users)
  end

  test "try listing related users from not logged in client" do
    assert :unauthenticated == remote_call(node1(), :list_related)
  end

  test "list related users successfully" do
    to_return = ["user1", "user2", "user3"]
    GameMock |> expect(:all_related, fn _ -> to_return end)
    assert {:ok, to_return} == remote_call(node2(), :list_related)
  end

  test "try sending invitation from not logged in client" do
    assert :unauthenticated == remote_call(node1(), {:invite, "username"})
  end

  test "try inviting non-existent user" do
    stub_invite_user()
    UserMock |> expect(:exists?, fn _name -> false end)

    assert :no_such_user == remote_call(node2(), {:invite, "invalid_username"})
  end

  test "inviting user for the second time should be ignored" do
    stub_invite_user()
    InvitationMock |> expect(:exists?, fn _, _ -> true end)

    assert :not_eligible == remote_call(node3(), {:invite, "username2"})
  end

  test "user tries to invite themselves" do
    stub_invite_user()

    assert :not_eligible == remote_call(node2(), {:invite, "username2"})
  end

  test "user invites someone who they're playing with" do
    stub_invite_user()
    GameMock |> expect(:exists?, fn _, _ -> true end)

    assert :not_eligible == remote_call(node2(), {:invite, "username3"})
  end

  test "users invite each other but starting game fails" do
    stub_invite_user()
    InvitationMock |> expect(:exists?, 2, fn from, _sto -> from == "username2" end)
    GameMock |> expect(:start, fn _, _ -> false end)

    assert :db_error == remote_call(node3(), {:invite, "username2"})
  end

  test "users invite each other successfully" do
    stub_invite_user()
    InvitationMock |> expect(:exists?, 2, fn from, _to -> from == "username2" end)
    GameMock |> expect(:start, fn _, _ -> true end)

    assert :ok == remote_call(node3(), {:invite, "username2"})
  end

  test "user tries to send invitation but insert query fails" do
    stub_invite_user()
    InvitationMock |> expect(:insert, fn _, _ -> false end)
    assert :db_error == remote_call(node3(), {:invite, "username2"})
  end

  test "user sends invitation successfully" do
    stub_invite_user()

    assert :ok == remote_call(node3(), {:invite, "username2"})
  end

  test "the client is called after sending invitation" do
    stub_invite_user()
    remote_call(node3(), {:invite, "username2"})
    assert :ok = received(node2(), :cast, {:add_invitation, "username3"})
  end

  test "the clients are called after mutual invitation" do
    stub_invite_user()
    InvitationMock |> expect(:exists?, 3, fn from, _to -> from == "username2" end)
    GameMock |> expect(:start, fn _, _ -> true end)
    remote_call(node3(), {:invite, "username2"})
    remote_call(node2(), {:invite, "username3"})
    assert :ok = received(node2(), :cast, {:add_question, "username3", 0})
    assert :ok = received(node3(), :cast, {:add_question, "username2", 0})
  end

  test "try accepting invitation from not logged in client" do
    assert :unauthenticated == remote_call(node1(), {:accept, "username1"})
  end

  test "try accepting invitation from a non-existent user" do
    stub_accept_invitation()
    UserMock |> expect(:exists?, fn _name -> false end)

    assert :no_such_user == remote_call(node2(), {:accept, "username1"})
  end

  test "try accepting non-existent invitation" do
    stub_accept_invitation()
    InvitationMock |> expect(:exists?, fn _, _ -> false end)

    assert :no_such_invitation == remote_call(node3(), {:accept, "username2"})
  end

  test "try accepting invitation but the query fails" do
    stub_accept_invitation()
    GameMock |> expect(:start, fn _, _ -> false end)

    assert :db_error == remote_call(node3(), {:accept, "username2"})
  end

  test "accept invitation successfully" do
    stub_accept_invitation()

    assert :ok == remote_call(node3(), {:accept, "username2"})
  end

  test "the clients are called after a game starts" do
    stub_accept_invitation()
    remote_call(node3(), {:accept, "username2"})
    assert :ok = received(node2(), :cast, {:add_question, "username3", 0})
    assert :ok = received(node3(), :cast, {:add_question, "username2", 0})
  end

  test "try declining invitation from not logged in client" do
    assert :unauthenticated == remote_call(node1(), {:decline, "username1"})
  end

  test "try declining invitation from a non-existent user" do
    stub_decline_invitation()
    UserMock |> expect(:exists?, fn _name -> false end)

    assert :no_such_user == remote_call(node3(), {:decline, "username2"})
  end

  test "try declining non-existent invitation" do
    stub_decline_invitation()
    InvitationMock |> expect(:exists?, fn _, _ -> false end)

    assert :no_such_invitation == remote_call(node3(), {:decline, "username2"})
  end

  test "try declining invitation but the query fails" do
    stub_decline_invitation()
    InvitationMock |> expect(:delete, fn _, _ -> false end)

    assert :db_error == remote_call(node3(), {:decline, "username2"})
  end

  test "decline invitation successfully" do
    stub_decline_invitation()

    assert :ok == remote_call(node3(), {:decline, "username2"})
  end

  test "try answering a question but the client is not not logged in" do
    assert :unauthenticated = remote_call(node1(), {:answer_question, "username2", "a"})
  end

  test "try answering a question from non-existent user" do
    stub_answer()
    UserMock |> expect(:exists?, fn _ -> false end)

    assert :no_such_user = remote_call(node3(), {:answer_question, "username1", "a"})
  end

  test "try answering a question but there's no game record" do
    stub_answer()
    GameMock |> expect(:exists?, fn _, _ -> false end)

    assert :no_such_game = remote_call(node3(), {:answer_question, "username2", "a"})
  end

  test "try answering a question but the answer is not a/b/c" do
    stub_answer()

    assert :invalid_response = remote_call(node3(), {:answer_question, "username2", "d"})
  end

  test "try answering a question but the answer is nil" do
    stub_answer()

    assert :invalid_response = remote_call(node3(), {:answer_question, "username2", nil})
  end

  test "try answering a question but there's no question in the db" do
    stub_answer()
    QuestionMock |> expect(:get_question_number, fn _ -> false end)

    assert :db_error = remote_call(node3(), {:answer_question, "username2", "a"})
  end

  test "try answering a question but the insert query fails" do
    stub_answer()
    GameMock |> expect(:answer_question, fn _, _, _ -> false end)

    assert :db_error = remote_call(node3(), {:answer_question, "username2", "a"})
  end

  test "a 'guess' message is being sent to the other user upon answering" do
    stub_answer()
    remote_call(node3(), {:answer_question, "username2", "a"})

    assert :ok = received(node3(), :cast, {:add_question, "username2", 0})
  end

  test "an 'answer' message is being sent to the user upon answering" do
    stub_answer()
    remote_call(node3(), {:answer_question, "username2", "a"})

    assert :ok = received(node2(), :cast, {:add_guess, "username3", 0, "a"})
  end

  test "answer a question when other user is not online" do
    stub_answer()

    assert :ok = remote_call(node3(), {:answer_question, "username1", "a"})
  end

  test "answer a question successfully" do
    stub_answer()

    assert :ok = remote_call(node3(), {:answer_question, "username2", "a"})
  end

  test "try guess a question but the client is not not logged in" do
    assert :unauthenticated = remote_call(node1(), {:guess_question, "username2", "a"})
  end

  test "try guessing a question but the user doesn't exist" do
    stub_guess()
    UserMock |> expect(:exists?, fn _ -> false end)

    assert :no_such_user = remote_call(node2(), {:guess_question, "username1", "a"})
  end

  test "try guessing a question but the guess is not valid" do
    stub_guess()

    assert :invalid_response = remote_call(node2(), {:guess_question, "username1", "d"})
  end

  test "try guessing a question but the guess is nil" do
    stub_guess()

    assert :invalid_response = remote_call(node2(), {:guess_question, "username1", nil})
  end

  test "try guessing a question but there's no such game" do
    stub_guess()
    GameMock |> expect(:exists?, fn _, _ -> false end)

    assert :no_such_game = remote_call(node2(), {:guess_question, "username1", "a"})
  end

  test "try guessing a question but db query fails" do
    stub_guess()
    GameMock |> expect(:guess_question, fn _, _, _ -> false end)

    assert :db_error = remote_call(node2(), {:guess_question, "username1", "a"})
  end

  test "a 'show' message is being sent to the other user upon guessing" do
    stub_guess()
    remote_call(node3(), {:guess_question, "username2", "a"})

    assert :ok = received(node2(), :cast, {:add_see, "username3", 0, "a", "a"})
  end

  test "guess a question when other user is not online" do
    stub_guess()

    assert :ok = remote_call(node3(), {:guess_question, "username1", "a"})
  end

  test "guess a question successfully" do
    stub_guess()

    assert :ok = remote_call(node3(), {:guess_question, "username2", "a"})
  end

  test "try getting score but the client is not logged in" do
    assert :unauthenticated = remote_call(node1(), {:get_score, "username2"})
  end

  test "try getting score but there's no such user" do
    UserMock |> expect(:exists?, fn _ -> false end)

    assert :no_such_user = remote_call(node2(), {:get_score, "username1"})
  end

  test "try getting score but there's no such game" do
    stub_get_score()
    GameMock |> expect(:exists?, fn _, _ -> false end)

    assert :no_such_game = remote_call(node2(), {:get_score, "username1"})
  end

  test "try getting score but get score query fails" do
    stub_get_score()
    GameMock |> expect(:get_score, fn _, _ -> :err end)

    assert :db_error = remote_call(node2(), {:get_score, "username1"})
  end

  test "try getting score but get s1 hits query fails" do
    stub_get_score()
    ScoreMock |> expect(:get_hits, fn _ -> :err end)

    assert :db_error = remote_call(node2(), {:get_score, "username1"})
  end

  test "try getting score but get s2 hits query fails" do
    stub_get_score()
    ScoreMock |> expect(:get_hits, fn _ -> {:ok, 0} end)
    ScoreMock |> expect(:get_hits, fn _ -> :err end)

    assert :db_error = remote_call(node2(), {:get_score, "username1"})
  end

  test "try getting score but get s1 misses query fails" do
    stub_get_score()
    ScoreMock |> expect(:get_misses, fn _ -> :err end)

    assert :db_error = remote_call(node2(), {:get_score, "username1"})
  end

  test "try getting score but get s2 misses query fails" do
    stub_get_score()
    ScoreMock |> expect(:get_misses, fn _ -> {:ok, 0} end)
    ScoreMock |> expect(:get_misses, fn _ -> :err end)

    assert :db_error = remote_call(node2(), {:get_score, "username1"})
  end

  test "getting score successfully" do
    stub_get_score()

    assert {:ok, 25.0, 25.0} = remote_call(node2(), {:get_score, "username1"})
  end

  test "score is calculated correctly" do
    stub_get_score()

    GameMock
    |> expect(
      :get_score,
      2,
      fn _, user1 -> if user1 == "username1", do: {:ok, 1}, else: {:ok, 2} end
    )

    expect(ScoreMock, :get_hits, 2, fn id -> if id == 1, do: {:ok, 1}, else: {:ok, 2} end)
    expect(ScoreMock, :get_misses, 2, fn id -> if id == 1, do: {:ok, 2}, else: {:ok, 1} end)

    assert {:ok, 66.67, 33.33} = remote_call(node2(), {:get_score, "username1"})
  end

  defp stub_register_user do
    stub(UserMock, :exists?, fn _name -> false end)
    stub(UserMock, :insert, fn _name, _ -> true end)
  end

  defp stub_unregister_user do
    UserMock |> stub(:get_password, fn _name -> "password" end)
    UserMock |> stub(:delete, fn _name -> true end)
  end

  defp stub_login do
    UserMock |> stub(:exists?, fn _name -> true end)
    UserMock |> stub(:get_password, fn _name -> "password" end)
    InvitationMock |> stub(:get_all_for, fn _ -> {:ok, ["username2"]} end)
    GameMock |> stub(:all_related, fn _ -> ["username3"] end)

    GameMock
    |> stub(
      :get_question,
      fn _, user -> if user == "username1", do: {:ok, 1}, else: {:ok, 2} end
    )

    QuestionMock |> stub(:get_question_number, fn num -> {:ok, num} end)
    QuestionMock |> stub(:get_question_answer, fn _ -> {:ok, :a} end)
    QuestionMock |> stub(:get_question_guess, fn _ -> {:ok, :b} end)
  end

  defp stub_answer do
    UserMock |> stub(:exists?, fn _ -> true end)
    GameMock |> stub(:exists?, fn _, _ -> true end)
    GameMock |> stub(:get_question, fn _, _ -> {:ok, 1} end)
    GameMock |> stub(:answer_question, fn _, _, _ -> true end)
    QuestionMock |> stub(:get_question_number, fn _ -> {:ok, 0} end)
  end

  defp stub_guess do
    UserMock |> stub(:exists?, fn _ -> true end)
    GameMock |> stub(:exists?, fn _, _ -> true end)
    GameMock |> stub(:get_question, fn _, _ -> {:ok, 1} end)
    QuestionMock |> stub(:get_question_number, fn _ -> {:ok, 0} end)
    QuestionMock |> stub(:get_question_answer, fn _ -> {:ok, "a"} end)
    QuestionMock |> stub(:get_question_guess, fn _ -> {:ok, "a"} end)
    GameMock |> stub(:guess_question, fn _, _, _ -> true end)
  end

  defp stub_get_score do
    UserMock |> stub(:exists?, fn _ -> true end)
    GameMock |> stub(:exists?, fn _, _ -> true end)
    GameMock |> stub(:get_score, fn _, _ -> {:ok, 1} end)
    ScoreMock |> stub(:get_hits, fn _ -> {:ok, 1} end)
    ScoreMock |> stub(:get_misses, fn _ -> {:ok, 3} end)
  end

  defp stub_invite_user do
    UserMock |> stub(:exists?, fn _name -> true end)
    GameMock |> stub(:exists?, fn _, _ -> false end)
    InvitationMock |> stub(:exists?, fn _, _ -> false end)
    InvitationMock |> stub(:insert, fn _, _ -> true end)
    GameMock |> stub(:get_question, fn _, _ -> {:ok, 0} end)
    QuestionMock |> stub(:get_question_number, fn _ -> {:ok, 0} end)
    GameMock |> stub(:start, fn _, _ -> true end)
  end

  defp stub_accept_invitation do
    UserMock |> stub(:exists?, fn _name -> true end)
    InvitationMock |> stub(:exists?, fn _, _ -> true end)
    GameMock |> stub(:get_question, fn _, _ -> {:ok, 0} end)
    QuestionMock |> stub(:get_question_number, fn _ -> {:ok, 0} end)
    GameMock |> stub(:start, fn _, _ -> true end)
  end

  defp stub_decline_invitation do
    UserMock |> stub(:exists?, fn _name -> true end)
    InvitationMock |> stub(:exists?, fn _, _ -> true end)
    InvitationMock |> stub(:delete, fn _, _ -> true end)
  end

  defp remote_call(node, args) do
    :rpc.call(node, GenServer, :call, [{:global, :quiz_server}, args])
  end

  defp server_pid, do: :global.whereis_name(:quiz_server)

  defp received(node, type, msg) do
    receive do
      {^node, ^type, ^msg} -> :ok
    after
      5_000 -> :time_out
    end
  end
end
