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
    # stub all external components
    stub_all()

    # start the server/the clients if they're down
    Server.Worker.start_link()
    :rpc.block_call(node1(), Client.Worker, :start_link, [])
    :rpc.block_call(node2(), Client.Worker, :start_link, [])
    :rpc.block_call(node3(), Client.Worker, :start_link, [])

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

  describe "register" do
    test "unsuccessful registration with empty username" do
      stub(UserMock, :exists?, fn _name -> false end)

      assert :invalid_username == call_server(node1(), :register, ["", "pass"])
    end

    test "unsuccessful registration with empty password" do
      stub(UserMock, :exists?, fn _name -> false end)

      assert :invalid_password == call_server(node1(), :register, ["username1", ""])
    end

    test "unsuccessful registration with ill-formatted username" do
      stub(UserMock, :exists?, fn _name -> false end)

      assert :invalid_username == call_server(node1(), :register, ["&@#", "password"])
    end

    test "unsuccessful registration for already registered client" do
      stub(UserMock, :exists?, fn _name -> false end)

      assert :already_registered == call_server(node2(), :register, ["username4", "password"])
    end

    test "unsuccessful registration for a client with already taken name" do
      UserMock |> expect(:exists?, fn _name -> true end)

      assert :taken == call_server(node1(), :register, ["username2", "password"])
    end

    test "unsuccessful registration due to failed insert query" do
      stub(UserMock, :exists?, fn _name -> false end)
      expect(UserMock, :insert, fn _name, _ -> false end)

      assert :db_error == call_server(node1(), :register, ["username1", "password"])
    end

    test "successfully registering a client" do
      stub(UserMock, :exists?, fn _name -> false end)

      assert :ok == call_server(node1(), :register, ["username1", "password"])
    end

    test "add user to online users list when registering" do
      assert "username2" == :sys.get_state(server_pid()) |> State.get_user(node2())
    end
  end

  describe "unregister" do
    test "failing to unregister a non-registered client" do
      assert :unauthenticated == call_server(node1(), :unregister, ["password"])
    end

    test "failing to unregister unauthenticated client" do
      assert :unauthenticated == call_server(node2(), :unregister, ["wrong_password"])
    end

    test "failing to unregister client when db fail occurs" do
      UserMock |> expect(:delete, fn _name -> false end)
      assert :db_error == call_server(node2(), :unregister, ["password"])
    end

    test "remove user from online users list when unregistering" do
      assert :ok == call_server(node2(), :unregister, ["password"])
    end

    test "successfully unregistering a client" do
      assert :ok == call_server(node2(), :unregister, ["password"])
    end
  end

  describe "login" do
    test "unsuccessful login for already logged in client" do
      stub_login()

      assert :already_logged_in == call_server(node2(), :login, ["username2", "password"])
    end

    test "unsuccessful login for unregistered user" do
      stub_login()
      UserMock |> expect(:exists?, fn _name -> false end)

      assert :wrong_credentials == call_server(node1(), :login, ["username1", "password"])
    end

    test "unsuccessful login because of wrong password" do
      stub_login()

      assert :wrong_credentials == call_server(node1(), :login, ["username1", "wrong_password"])
    end

    test "unsuccessful login because of empty string password" do
      stub_login()

      assert :wrong_credentials == call_server(node1(), :login, ["username1", ""])
    end

    test "unsuccessful login because of nil password" do
      stub_login()

      assert :wrong_credentials == call_server(node1(), :login, ["username1", nil])
    end

    test "successful login" do
      stub_login()

      assert :ok == call_server(node1(), :login, ["username1", "password"])
    end

    test "invitations are sent after login" do
      stub_login()
      ClientMock |> expect(:cast_invitation, fn _, _ -> :ok end)
      ClientMock |> stub(:cast_to_see, fn _, _, _, _, _ -> :ok end)
      call_server(node1(), :login, ["username1", "password"])
    end

    test "questions for answering/guessing are sent after login" do
      stub_login()
      QuestionMock |> expect(:get_question_answer, 2, fn _ -> {:ok, nil} end)
      ClientMock |> expect(:cast_invitation, fn _, _ -> :ok end)
      ClientMock |> expect(:cast_to_answer, fn _, _, _ -> :ok end)

      call_server(node1(), :login, ["username1", "password"])
    end

    test "questions for guessing are sent after login" do
      stub_login()
      QuestionMock |> expect(:get_question_guess, 2, fn _ -> {:ok, nil} end)
      ClientMock |> expect(:cast_invitation, fn _, _ -> :ok end)
      ClientMock |> expect(:cast_to_guess, fn _, _, _, _ -> :ok end)
      call_server(node1(), :login, ["username1", "password"])
    end

    test "questions for review are sent after login" do
      stub_login()

      ClientMock |> stub(:cast_invitation, fn _, _ -> :ok end)
      ClientMock |> expect(:cast_to_see, fn _, _, _, _, _ -> :ok end)
      call_server(node1(), :login, ["username1", "password"])
    end

    test "successful login of a user from second client" do
      stub_login()

      assert :ok == call_server(node1(), :login, ["username2", "password"])
    end

    test "add user to online users list when logging in" do
      stub_login()
      assert :ok = call_server(node1(), :login, ["username1", "password"])
      assert "username1" == :sys.get_state(server_pid()) |> State.get_user(node1())
    end
  end

  describe "disconnect" do
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
  end

  describe "list users" do
    test "try listing users from not logged in client" do
      assert :unauthenticated == call_server(node1(), :list_users, [])
    end

    test "list users successfully" do
      to_return = ["user1", "user2", "user3"]
      UserMock |> expect(:all, fn -> to_return end)
      assert {:ok, to_return} == call_server(node2(), :list_users, [])
    end
  end

  describe "list related users" do
    test "try listing related users from not logged in client" do
      assert :unauthenticated == call_server(node1(), :list_related, [])
    end

    test "list related users successfully" do
      to_return = ["user1", "user2", "user3"]
      GameMock |> expect(:all_related, fn _ -> to_return end)
      assert {:ok, to_return} == call_server(node2(), :list_related, [])
    end
  end

  describe "invite" do
    test "try sending invitation from not logged in client" do
      assert :unauthenticated == call_server(node1(), :invite, ["username"])
    end

    test "try inviting non-existent user" do
      stub_invite_user()
      UserMock |> expect(:exists?, fn _name -> false end)

      assert :no_such_user == call_server(node2(), :invite, ["invalid_username"])
    end

    test "inviting user for the second time should be ignored" do
      stub_invite_user()
      InvitationMock |> expect(:exists?, fn _, _ -> true end)

      assert :not_eligible == call_server(node3(), :invite, ["username2"])
    end

    test "user tries to invite themselves" do
      stub_invite_user()

      assert :not_eligible == call_server(node2(), :invite, ["username2"])
    end

    test "user invites someone who they're playing with" do
      stub_invite_user()
      GameMock |> expect(:exists?, fn _, _ -> true end)

      assert :not_eligible == call_server(node2(), :invite, ["username3"])
    end

    test "users invite each other but starting game fails" do
      stub_invite_user()
      InvitationMock |> expect(:exists?, 2, fn from, _sto -> from == "username2" end)
      GameMock |> expect(:start, fn _, _ -> false end)

      assert :db_error == call_server(node3(), :invite, ["username2"])
    end

    test "users invite each other successfully" do
      stub_invite_user()
      InvitationMock |> expect(:exists?, 2, fn from, _to -> from == "username2" end)
      GameMock |> expect(:start, fn _, _ -> true end)

      assert :ok == call_server(node3(), :invite, ["username2"])
    end

    test "user tries to send invitation but insert query fails" do
      stub_invite_user()
      InvitationMock |> expect(:insert, fn _, _ -> false end)
      assert :db_error == call_server(node3(), :invite, ["username2"])
    end

    test "user sends invitation successfully" do
      stub_invite_user()

      assert :ok == call_server(node3(), :invite, ["username2"])
    end

    test "the client is called after sending invitation" do
      stub_invite_user()
      ClientMock |> expect(:cast_invitation, fn _, _ -> :ok end)

      call_server(node3(), :invite, ["username2"])
    end

    test "the clients are called after mutual invitation" do
      stub_invite_user()
      InvitationMock |> expect(:exists?, 3, fn from, _to -> from == "username2" end)
      GameMock |> expect(:start, fn _, _ -> true end)

      ClientMock |> expect(:cast_to_answer, 2, fn _, _, _ -> true end)

      call_server(node3(), :invite, ["username2"])
      call_server(node2(), :invite, ["username3"])
    end
  end

  describe "accept invitation" do
    test "try accepting invitation from not logged in client" do
      assert :unauthenticated == call_server(node1(), :accept, ["username1"])
    end

    test "try accepting invitation from a non-existent user" do
      UserMock |> expect(:exists?, fn _name -> false end)

      assert :no_such_user == call_server(node2(), :accept, ["username1"])
    end

    test "try accepting non-existent invitation" do
      InvitationMock |> expect(:exists?, fn _, _ -> false end)

      assert :no_such_invitation == call_server(node3(), :accept, ["username2"])
    end

    test "try accepting invitation but the query fails" do
      GameMock |> expect(:start, fn _, _ -> false end)

      assert :db_error == call_server(node3(), :accept, ["username2"])
    end

    test "accept invitation successfully" do
      assert :ok == call_server(node3(), :accept, ["username2"])
    end

    test "the clients are called after a game starts" do
      ClientMock |> expect(:cast_to_answer, 2, fn _, _, _ -> true end)
      call_server(node3(), :accept, ["username2"])
    end
  end

  describe "decline invitation" do
    test "try declining invitation from not logged in client" do
      assert :unauthenticated == call_server(node1(), :decline, ["username1"])
    end

    test "try declining invitation from a non-existent user" do
      UserMock |> expect(:exists?, fn _name -> false end)

      assert :no_such_user == call_server(node3(), :decline, ["username2"])
    end

    test "try declining non-existent invitation" do
      InvitationMock |> expect(:exists?, fn _, _ -> false end)

      assert :no_such_invitation == call_server(node3(), :decline, ["username2"])
    end

    test "try declining invitation but the query fails" do
      InvitationMock |> expect(:delete, fn _, _ -> false end)

      assert :db_error == call_server(node3(), :decline, ["username2"])
    end

    test "decline invitation successfully" do
      assert :ok == call_server(node3(), :decline, ["username2"])
    end
  end

  describe "answer question" do
    test "try answering a question but the client is not not logged in" do
      assert :unauthenticated = call_server(node1(), :answer_question, ["username2", "a"])
    end

    test "try answering a question from non-existent user" do
      UserMock |> expect(:exists?, fn _ -> false end)

      assert :no_such_user = call_server(node3(), :answer_question, ["username1", "a"])
    end

    test "try answering a question but there's no game record" do
      GameMock |> expect(:exists?, fn _, _ -> false end)

      assert :no_such_game = call_server(node3(), :answer_question, ["username2", "a"])
    end

    test "try answering a question but the answer is not a/b/c" do
      assert :invalid_response = call_server(node3(), :answer_question, ["username2", "d"])
    end

    test "try answering a question but the answer is nil" do
      assert :invalid_response = call_server(node3(), :answer_question, ["username2", nil])
    end

    test "try answering a question but there's no question in the db" do
      QuestionMock |> expect(:get_question_number, fn _ -> false end)

      assert :db_error = call_server(node3(), :answer_question, ["username2", "a"])
    end

    test "try answering a question but the insert query fails" do
      GameMock |> expect(:answer_question, fn _, _, _ -> false end)

      assert :db_error = call_server(node3(), :answer_question, ["username2", "a"])
    end

    test "messages are being sent to the users upon answering" do
      ClientMock |> expect(:cast_to_answer, fn _, _, _ -> :ok end)
      ClientMock |> expect(:cast_to_guess, fn _, _, _, _ -> :ok end)

      call_server(node3(), :answer_question, ["username2", "a"])
    end

    test "answer a question when other user is not online" do
      assert :ok = call_server(node3(), :answer_question, ["username1", "a"])
    end

    test "answer a question successfully" do
      assert :ok = call_server(node3(), :answer_question, ["username2", "a"])
    end
  end

  describe "guess question" do
    test "try guess a question but the client is not not logged in" do
      assert :unauthenticated = call_server(node1(), :guess_question, ["username2", "a"])
    end

    test "try guessing a question but the user doesn't exist" do
      UserMock |> expect(:exists?, fn _ -> false end)

      assert :no_such_user = call_server(node2(), :guess_question, ["username1", "a"])
    end

    test "try guessing a question but the guess is not valid" do
      assert :invalid_response = call_server(node2(), :guess_question, ["username1", "d"])
    end

    test "try guessing a question but the guess is nil" do
      assert :invalid_response = call_server(node2(), :guess_question, ["username1", nil])
    end

    test "try guessing a question but there's no such game" do
      GameMock |> expect(:exists?, fn _, _ -> false end)

      assert :no_such_game = call_server(node2(), :guess_question, ["username1", "a"])
    end

    test "try guessing a question but db query fails" do
      GameMock |> expect(:guess_question, fn _, _, _ -> false end)

      assert :db_error = call_server(node2(), :guess_question, ["username1", "a"])
    end

    test "a 'show' message is being sent to the other user upon guessing" do
      ClientMock |> expect(:cast_to_see, fn _, _, _, _, _ -> :ok end)
      call_server(node3(), :guess_question, ["username2", "a"])
    end

    test "guess a question when other user is not online" do
      assert :ok = call_server(node3(), :guess_question, ["username1", "a"])
    end

    test "guess a question successfully" do
      assert :ok = call_server(node3(), :guess_question, ["username2", "a"])
    end
  end

  describe "get score" do
    test "try getting score but the client is not logged in" do
      assert :unauthenticated = call_server(node1(), :get_score, ["username2"])
    end

    test "try getting score but there's no such user" do
      UserMock |> expect(:exists?, fn _ -> false end)

      assert :no_such_user = call_server(node2(), :get_score, ["username1"])
    end

    test "try getting score but there's no such game" do
      GameMock |> expect(:exists?, fn _, _ -> false end)

      assert :no_such_game = call_server(node2(), :get_score, ["username1"])
    end

    test "try getting score but get score query fails" do
      GameMock |> expect(:get_score, fn _, _ -> :err end)

      assert :db_error = call_server(node2(), :get_score, ["username1"])
    end

    test "try getting score but get s1 hits query fails" do
      ScoreMock |> expect(:get_hits, fn _ -> :err end)

      assert :db_error = call_server(node2(), :get_score, ["username1"])
    end

    test "try getting score but get s2 hits query fails" do
      ScoreMock |> expect(:get_hits, fn _ -> {:ok, 0} end)
      ScoreMock |> expect(:get_hits, fn _ -> :err end)

      assert :db_error = call_server(node2(), :get_score, ["username1"])
    end

    test "try getting score but get s1 misses query fails" do
      ScoreMock |> expect(:get_misses, fn _ -> :err end)

      assert :db_error = call_server(node2(), :get_score, ["username1"])
    end

    test "try getting score but get s2 misses query fails" do
      ScoreMock |> expect(:get_misses, fn _ -> {:ok, 0} end)
      ScoreMock |> expect(:get_misses, fn _ -> :err end)

      assert :db_error = call_server(node2(), :get_score, ["username1"])
    end

    test "getting score successfully" do
      assert {:ok, 25.0, 25.0} = call_server(node2(), :get_score, ["username1"])
    end

    test "score is calculated correctly" do
      GameMock
      |> expect(
        :get_score,
        2,
        fn _, user1 -> if user1 == "username1", do: {:ok, 1}, else: {:ok, 2} end
      )

      expect(ScoreMock, :get_hits, 2, fn id -> if id == 1, do: {:ok, 1}, else: {:ok, 2} end)
      expect(ScoreMock, :get_misses, 2, fn id -> if id == 1, do: {:ok, 2}, else: {:ok, 1} end)

      assert {:ok, 66.67, 33.33} = call_server(node2(), :get_score, ["username1"])
    end
  end

  def stub_all do
    Mox.stub_with(Application.get_env(:engine, :user), DummyUser)
    Mox.stub_with(Application.get_env(:engine, :game), DummyGame)
    Mox.stub_with(Application.get_env(:engine, :question), DummyQuestion)
    Mox.stub_with(Application.get_env(:engine, :invitation), DummyInvitation)
    Mox.stub_with(Application.get_env(:engine, :score), DummyScore)
    Mox.stub_with(Application.get_env(:engine, :client), DummyClient)
  end

  defp stub_login do
    stub(
      GameMock,
      :get_question,
      fn _, user -> if user == "username1", do: {:ok, 1}, else: {:ok, 2} end
    )
  end

  defp stub_invite_user do
    GameMock |> stub(:exists?, fn _, _ -> false end)
    InvitationMock |> stub(:exists?, fn _, _ -> false end)
  end

  def call_server(node, func, args) do
    :rpc.call(node, Server.Worker, func, args)
  end

  defp server_pid, do: :global.whereis_name(:dykm_server)
end
