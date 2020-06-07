defmodule Client.WorkerTest do
  use ExUnit.Case

  require Logger
  alias Client.Worker
  alias Client.State

  setup do
    pid = Process.whereis(:quiz_client)
    # IO.puts("client: #{inspect(pid)}")
    # IO.puts("state: #{inspect(:sys.get_state(pid))}")
    # IO.puts("state1: #{inspect(:sys.replace_state(pid, fn _ -> 12 end))}")
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
      assert :server_answer == Worker.register("user", "pass")
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
      assert :server_answer == Worker.login("user", "pass")
    end
  end

  describe "unregister" do
    test "successful unregistration" do
      client_pid()
      |> :sys.replace_state(fn state -> State.set_username(state, "some_name") end)

      assert :server_answer == Worker.unregister()
    end

    test "trying to unregister without registering" do
      assert :not_registered == Worker.unregister()
    end

    test "state is nulled out after unregistering" do
      client_pid()
      |> :sys.replace_state(fn state -> State.set_username(state, "some_name") end)

      Worker.unregister()
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
      assert nil == Worker.get_to_guess("some_name")
    end

    test "guess a question successfully" do
      client_pid()
      |> :sys.replace_state(fn state -> State.put_to_guess(state, "some_name", {1, "a"}) end)

      assert {Worker.fetch_question(1), "a"} == Worker.get_to_guess("some_name")
    end

    test "guess a question but server sends invalid guess format" do
      client_pid()
      |> :sys.replace_state(fn state -> State.put_to_guess(state, "some_name", {"a", 1}) end)

      catch_exit(Worker.get_to_guess("some_name"))
    end
  end

  describe "get question to answer" do
    test "there's no question to answer" do
      assert nil == Worker.get_to_answer("some_name")
    end

    test "answer a question but server sends invalid answer format" do
      client_pid()
      |> :sys.replace_state(fn state -> State.put_to_answer(state, "some_name", {1, "a"}) end)

      catch_exit(Worker.get_to_answer("some_name"))
    end

    test "answer a question successfully" do
      client_pid()
      |> :sys.replace_state(fn state -> State.put_to_answer(state, "some_name", 1) end)

      assert Worker.fetch_question(1) == Worker.get_to_answer("some_name")
    end
  end

  describe "get question to see" do
    test "there's no question to see" do
      assert nil == Worker.get_to_see("some_name")
    end

    test "see a see but server sends invalid format" do
      client_pid()
      |> :sys.replace_state(fn state -> State.put_to_see(state, "some_name", {1, "a"}) end)

      catch_exit(Worker.get_to_see("some_name"))
    end

    test "see a question successfully" do
      client_pid()
      |> :sys.replace_state(fn state -> State.put_to_see(state, "some_name", {1, "a", "b"}) end)

      assert {Worker.fetch_question(1), "a", "b"} == Worker.get_to_see("some_name")
    end
  end

  defp client_pid, do: Process.whereis(:quiz_client)
end
