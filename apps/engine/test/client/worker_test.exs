defmodule Client.WorkerTest do
  use ExUnit.Case

  import Mox
  setup :verify_on_exit!
  setup :set_mox_global

  require Logger
  alias Client.Worker
  alias Client.State

  setup_all do
    Mox.defmock(Application.get_env(:engine, :server_worker), for: Server.Behaviour)
    :ok
  end

  setup do
    Mox.stub_with(Application.get_env(:engine, :server_worker), DummyServer)

    Client.Worker.start_link()
    # assert {:ok, "sad"} == Process.whereis(:quiz_client)
    Process.whereis(:quiz_client) |> :sys.replace_state(fn _ -> State.new() end)
    :ok
  end

  describe "register" do
    test "registration fails when the client has a user associated with it" do
      :sys.replace_state(client_pid(), fn state -> State.set_username(state, "some_name") end)

      assert :already_registered == Worker.register("name", "pass")
    end

    test "trying to register but the name is not a string" do
      assert :invalid_format == Worker.register(:name, "pass")
    end

    test "trying to register but the name is empty string" do
      assert :invalid_format == Worker.register("", "pass")
    end

    test "trying to register but the password is not a string" do
      assert :invalid_format == Worker.register("user", :pass)
    end

    test "trying to register but the password is empty string" do
      assert :invalid_format == Worker.register("user", "")
    end

    test "successful registration" do
      assert :ok == Worker.register("user", "pass")
    end

    test "a call to the server has been made" do
      ServerMock |> expect(:register, fn _, _ -> :ok end)
      Worker.register("user", "pass")
    end
  end

  describe "login" do
    test "login fails when the client has a user associated with it" do
      client_pid()
      |> :sys.replace_state(fn state -> State.set_username(state, "some_name") end)

      assert :already_registered == Worker.login("name", "pass")
    end

    test "trying to login but the name is not a string" do
      assert :invalid_format == Worker.login(:name, "pass")
    end

    test "trying to login but the name is empty string" do
      assert :invalid_format == Worker.login("", "pass")
    end

    test "trying to login but the password is not a string" do
      assert :invalid_format == Worker.login("user", :pass)
    end

    test "trying to login but the password is empty string" do
      assert :invalid_format == Worker.login("user", "")
    end

    test "successful login" do
      assert :ok == Worker.login("user", "pass")
    end

    test "a call to the server has been made" do
      ServerMock |> expect(:login, fn _, _ -> :ok end)
      Worker.login("user", "pass")
    end
  end

  describe "unregister" do
    test "successful unregistration" do
      client_pid()
      |> :sys.replace_state(fn state -> State.set_username(state, "some_name") end)

      assert :ok == Worker.unregister("pass")
    end

    test "a call to the server has been made" do
      client_pid()
      |> :sys.replace_state(fn state -> State.set_username(state, "some_name") end)

      ServerMock |> expect(:unregister, fn _ -> :ok end)
      Worker.unregister("pass")
    end

    test "trying to unregister without registering" do
      assert :not_registered == Worker.unregister("pass")
    end

    test "state is nulled out after unregistering" do
      client_pid()
      |> :sys.replace_state(fn state -> State.set_username(state, "some_name") end)

      Worker.unregister("pass")
      assert State.new() == :sys.get_state(client_pid())
    end
  end

  describe "get username" do
    test "get nil username before login" do
      assert nil == Worker.username()
    end

    test "get username successfully" do
      client_pid()
      |> :sys.replace_state(fn state -> State.set_username(state, "some_name") end)

      assert "some_name" == Worker.username()
    end
  end

  describe "get invitations" do
    test "get empty set if there's no invitations" do
      assert MapSet.new() == Worker.get_invitations()
    end

    test "get all invitations successfully" do
      client_pid()
      |> :sys.replace_state(fn state -> State.add_invitation(state, "some_name") end)

      assert MapSet.new(["some_name"]) == Worker.get_invitations()
    end
  end

  describe "get question to guess" do
    test "there's no question to guess" do
      assert {:err, :no_such_question} == Worker.get_to_guess("some_name")
    end

    test "guess a question successfully" do
      client_pid()
      |> :sys.replace_state(fn state -> State.put_to_guess(state, "some_name", {1, "a"}) end)

      assert :ok == Worker.get_to_guess("some_name") |> elem(0)
    end

    test "guess a question but server sends invalid guess format" do
      client_pid()
      |> :sys.replace_state(fn state -> State.put_to_guess(state, "some_name", {"a", 1}) end)

      assert {:err, :invalid_format} == Worker.get_to_guess("some_name")
    end
  end

  describe "get question to answer" do
    test "there's no question to answer" do
      assert {:err, :no_such_question} == Worker.get_to_answer("some_name")
    end

    test "answer a question but server sends invalid answer format" do
      client_pid()
      |> :sys.replace_state(fn state -> State.put_to_answer(state, "some_name", {1, "a"}) end)

      assert {:err, :invalid_format} == Worker.get_to_answer("some_name")
    end

    test "answer a question successfully" do
      client_pid()
      |> :sys.replace_state(fn state -> State.put_to_answer(state, "some_name", 1) end)

      assert :ok == Worker.get_to_answer("some_name") |> elem(0)
    end
  end

  describe "get question to see" do
    test "there's no question to see" do
      assert {:err, :no_such_question} == Worker.get_to_see("some_name")
    end

    test "see a see but server sends invalid format" do
      client_pid()
      |> :sys.replace_state(fn state -> State.put_to_see(state, "some_name", {1, "a"}) end)

      assert {:err, :invalid_format} = Worker.get_to_see("some_name")
    end

    test "see a question successfully" do
      client_pid()
      |> :sys.replace_state(fn state -> State.put_to_see(state, "some_name", {1, "a", "b"}) end)

      assert :ok == Worker.get_to_see("some_name") |> elem(0)
    end
  end

  describe "get score" do
    test "get score successfully" do
      assert {:ok, 50.0, 50.0} == Worker.get_score("some_name")
    end

    test "a call to the server has been made" do
      ServerMock |> expect(:get_score, fn _ -> {:ok, 0, 0} end)

      Worker.get_score("some_name")
    end
  end

  describe "list users" do
    test "list related users successfully" do
      assert {:ok, []} == Worker.list_related()
    end

    test "a call to the server has been made when listing related users" do
      ServerMock |> expect(:list_related, fn -> {:ok, []} end)

      Worker.list_related()
    end

    test "list related users but the server returns error" do
      ServerMock |> stub(:list_related, fn -> :unauthenticated end)
      assert {:err, :unauthenticated} == Worker.list_related()
    end

    test "list related users ignoring own username" do
      :sys.replace_state(client_pid(), fn state -> State.set_username(state, "some_name") end)
      ServerMock |> stub(:list_related, fn -> {:ok, ["some_name"]} end)
      assert {:ok, []} == Worker.list_related()
    end

    test "list all users successfully" do
      assert {:ok, []} == Worker.list_registered()
    end

    test "a call to the server has been made when listing all users" do
      ServerMock |> expect(:list_users, fn -> {:ok, []} end)

      Worker.list_registered()
    end

    test "list all users but the server returns error" do
      ServerMock |> stub(:list_users, fn -> :unauthenticated end)
      assert {:err, :unauthenticated} == Worker.list_registered()
    end

    test "list all users ignoring own username" do
      :sys.replace_state(client_pid(), fn state -> State.set_username(state, "some_name") end)
      ServerMock |> stub(:list_users, fn -> {:ok, ["some_name"]} end)
      assert {:ok, []} == Worker.list_registered()
    end
  end

  describe "guess" do
    test "try to give a guess other that a/b/c" do
      :sys.replace_state(client_pid(), fn state ->
        State.put_to_guess(state, "some_name", {"q", "a"})
      end)

      assert {:err, :invalid_format} == Worker.give_guess("some_name", "d")
    end

    test "try to give a guess without a question to exist" do
      assert {:err, :no_such_question} == Worker.give_guess("some_name", "a")
    end

    test "try to give a guess but the server returns an error" do
      :sys.replace_state(client_pid(), fn state ->
        State.put_to_guess(state, "some_name", {"q", "a"})
      end)

      ServerMock |> stub(:guess_question, fn _, _ -> :internal_error end)

      assert {:err, :internal_error} == Worker.give_guess("some_name", "a")
    end

    test "give a correct guess successfully" do
      :sys.replace_state(client_pid(), fn state ->
        State.put_to_guess(state, "some_name", {"q", "a"})
      end)

      assert {:ok, true} == Worker.give_guess("some_name", "a")
    end

    test "give a incorrect guess successfully" do
      :sys.replace_state(client_pid(), fn state ->
        State.put_to_guess(state, "some_name", {"q", "a"})
      end)

      assert {:ok, false} == Worker.give_guess("some_name", "b")
    end

    test "a call to the server has been made" do
      :sys.replace_state(client_pid(), fn state ->
        State.put_to_guess(state, "some_name", {"q", "a"})
      end)

      ServerMock |> expect(:guess_question, fn _, _ -> :ok end)

      Worker.give_guess("some_name", "b")
    end

    test "remove the guess from the internal state upon success" do
      :sys.replace_state(client_pid(), fn state ->
        State.put_to_guess(state, "some_name", {"q", "a"})
      end)

      assert {:ok, false} == Worker.give_guess("some_name", "b")
      assert nil == :sys.get_state(client_pid()) |> State.get_to_guess("some_name")
    end
  end

  describe "answer" do
    test "try to give an answer other that a/b/c" do
      :sys.replace_state(client_pid(), fn state ->
        State.put_to_answer(state, "some_name", "q")
      end)

      assert {:err, :invalid_format} == Worker.give_answer("some_name", "d")
    end

    test "try to give an answer without a question to exist" do
      assert {:err, :no_such_question} == Worker.give_answer("some_name", "a")
    end

    test "try to give an answer but the server returns an error" do
      :sys.replace_state(client_pid(), fn state ->
        State.put_to_answer(state, "some_name", "q")
      end)

      ServerMock |> stub(:answer_question, fn _, _ -> :internal_error end)

      assert {:err, :internal_error} == Worker.give_answer("some_name", "a")
    end

    test "give an answer successfully" do
      :sys.replace_state(client_pid(), fn state ->
        State.put_to_answer(state, "some_name", "q")
      end)

      assert :ok == Worker.give_answer("some_name", "a")
    end

    test "a call to the server has been made" do
      :sys.replace_state(client_pid(), fn state ->
        State.put_to_answer(state, "some_name", "q")
      end)

      ServerMock |> expect(:answer_question, fn _, _ -> :ok end)

      Worker.give_answer("some_name", "a")
    end

    test "remove the answer from the internal state upon success" do
      :sys.replace_state(client_pid(), fn state ->
        State.put_to_answer(state, "some_name", "q")
      end)

      assert :ok == Worker.give_answer("some_name", "b")
      assert nil == :sys.get_state(client_pid()) |> State.get_to_answer("some_name")
    end
  end

  describe "invite" do
    test "invite user successfully" do
      assert :ok == Worker.invite("some_name")
    end

    test "a call to the server has been made" do
      ServerMock |> expect(:invite, fn _ -> :ok end)
      Worker.invite("some_name")
    end
  end

  describe "accept invitation" do
    test "try to accept non-existent invitation" do
      assert {:err, :no_such_user} == Worker.accept("some_name")
    end

    test "try to accept invitation but the server returns error" do
      :sys.replace_state(client_pid(), fn state ->
        State.add_invitation(state, "some_name")
      end)

      ServerMock |> stub(:accept, fn _ -> :internal_error end)
      assert {:err, :internal_error} == Worker.accept("some_name")
    end

    test "a call to the server has been made" do
      :sys.replace_state(client_pid(), fn state ->
        State.add_invitation(state, "some_name")
      end)

      ServerMock |> expect(:accept, fn _ -> :internal_error end)
      Worker.accept("some_name")
    end

    test "accept invitation successfully" do
      :sys.replace_state(client_pid(), fn state ->
        State.add_invitation(state, "some_name")
      end)

      assert :ok == Worker.accept("some_name")
    end

    test "remove invitation from inner state upon success" do
      :sys.replace_state(client_pid(), fn state ->
        State.add_invitation(state, "some_name")
      end)

      assert :ok == Worker.accept("some_name")
      assert MapSet.new() == :sys.get_state(client_pid()) |> State.get_invitations()
    end
  end

  describe "decline invitation" do
    test "try to decline non-existent invitation" do
      assert {:err, :no_such_user} == Worker.decline("some_name")
    end

    test "try to decline invitation but the server returns error" do
      :sys.replace_state(client_pid(), fn state ->
        State.add_invitation(state, "some_name")
      end)

      ServerMock |> stub(:decline, fn _ -> :internal_error end)
      assert {:err, :internal_error} == Worker.decline("some_name")
    end

    test "a call to the server has been made" do
      :sys.replace_state(client_pid(), fn state ->
        State.add_invitation(state, "some_name")
      end)

      ServerMock |> expect(:decline, fn _ -> :internal_error end)
      Worker.decline("some_name")
    end

    test "decline invitation successfully" do
      :sys.replace_state(client_pid(), fn state ->
        State.add_invitation(state, "some_name")
      end)

      assert :ok == Worker.decline("some_name")
    end

    test "remove invitation from inner state upon success" do
      :sys.replace_state(client_pid(), fn state ->
        State.add_invitation(state, "some_name")
      end)

      assert :ok == Worker.decline("some_name")
      assert MapSet.new() == :sys.get_state(client_pid()) |> State.get_invitations()
    end
  end

  describe "methods for the server to call" do
    test "casted invitations have to be added to the internal state" do
      Worker.cast_invitation(:quiz_client, "some_name")

      assert true ==
               :sys.get_state(:quiz_client)
               |> State.get_invitations()
               |> MapSet.member?("some_name")
    end

    test "casted 'answer' questions have to be added to the internal state" do
      Worker.cast_to_answer(:quiz_client, "some_name", 0)

      assert 0 ==
               :sys.get_state(:quiz_client)
               |> State.get_to_answer("some_name")
    end

    test "casted 'guess' questions have to be added to the internal state" do
      Worker.cast_to_guess(:quiz_client, "some_name", 0, "a")

      assert {0, "a"} ==
               :sys.get_state(:quiz_client)
               |> State.get_to_guess("some_name")
    end

    test "casted 'see' questions have to be added to the internal state" do
      Worker.cast_to_see(:quiz_client, "some_name", 0, "a", "b")

      assert {0, "a", "b"} ==
               :sys.get_state(:quiz_client)
               |> State.get_to_see("some_name")
    end
  end

  defp client_pid, do: Process.whereis(:quiz_client)
end
