defmodule Client.WorkerTest do
  use ExUnit.Case

  require Logger

  setup do
    {:ok, _} = TestServer.start_link()
    {:ok, _} = Client.Worker.start_link()
    GenServer.call(:quiz_client, {:register, "username2"})
    :ok
  end

  test "successful registration" do
    GenServer.call(:quiz_client, :unregister)
    assert :registered == GenServer.call(:quiz_client, {:register, "username2"})
  end

  test "trying to register already registered" do
    assert :already_registered == GenServer.call(:quiz_client, {:register, "username1"})
  end

  test "trying to register with a taken name" do
    GenServer.call(:quiz_client, :unregister)
    assert :taken == GenServer.call(:quiz_client, {:register, "username1"})
  end

  test "successful unregistration" do
    assert :unregistered == GenServer.call(:quiz_client, :unregister)
  end

  test "trying to unregister without registering" do
    GenServer.call(:quiz_client, :unregister)
    assert :not_registered == GenServer.call(:quiz_client, :unregister)
  end

  test "receiving an invitation from client" do
    GenServer.cast({:global, :quiz_server}, {:client_send_invitation, "username1", "username2"})
    state()
    assert true == GenServer.call(:quiz_client, :see_invitations) |> Map.has_key?("username1")
  end

  test "accepting an invitation" do
    GenServer.cast({:global, :quiz_server}, {:client_send_invitation, "username1", "username2"})
    GenServer.cast(:quiz_client, {:accept, "username1"})
    assert false == GenServer.call(:quiz_client, :see_invitations) |> Map.has_key?("username1")
  end

  test "declining an invitation" do
    GenServer.cast({:global, :quiz_server}, {:client_send_invitation, "username1", "username2"})
    GenServer.cast(:quiz_client, {:decline, "username1"})
    assert false == GenServer.call(:quiz_client, :see_invitations) |> Map.has_key?("username1")
  end

  test "having question to answer" do
    GenServer.cast({:global, :quiz_server}, {:client_send_to_answer, "username1", "username2"})
    state()
    assert true == GenServer.call(:quiz_client, :get_to_answer) |> Map.has_key?("username1")
  end

  test "answering a question" do
    GenServer.cast({:global, :quiz_server}, {:client_send_to_answer, "username1", "username2"})
    state()
    GenServer.cast(:quiz_client, {:answer, "username1", :a})
    assert false == GenServer.call(:quiz_client, :get_to_answer) |> Map.has_key?("username1")
  end

  test "giving invalid answer" do
    GenServer.cast(
      {:global, :quiz_server},
      {:client_send_to_answer, "username1", "username2"}
    )

    state()
    GenServer.cast(:quiz_client, {:answer, "username1", :d})
    assert true == GenServer.call(:quiz_client, :get_to_answer) |> Map.has_key?("username1")
  end

  test "trying to send answer to unregistered client" do
    to_answer = GenServer.call(:quiz_client, :get_to_answer)
    GenServer.cast(:client1, {:answer, "username3", :a})
    assert to_answer == GenServer.call(:quiz_client, :get_to_answer)
  end

  test "having question to guess" do
    GenServer.cast({:global, :quiz_server}, {:client_send_to_guess, "username1", "username2", :a})
    state()
    assert true == GenServer.call(:quiz_client, :get_to_guess) |> Map.has_key?("username1")
  end

  test "giving a right guess" do
    start_game()
    GenServer.cast({:global, :quiz_server}, {:client_send_to_guess, "username1", "username2", :a})
    state()
    assert true == GenServer.call(:quiz_client, {:guess, "username1", :a})
  end

  test "giving a wrong guess" do
    start_game()
    GenServer.cast({:global, :quiz_server}, {:client_send_to_guess, "username1", "username2", :a})
    state()
    assert false == GenServer.call(:quiz_client, {:guess, "username1", :b})
  end

  test "giving invalid guess" do
    GenServer.cast({:global, :quiz_server}, {:client_send_to_guess, "username1", "username2", :a})
    state()
    assert :error == GenServer.call(:quiz_client, {:guess, "username1", :d})
  end

  test "trying to guess question from unregistered client" do
    to_answer = GenServer.call(:quiz_client, :get_to_guess)
    state()
    GenServer.cast(:client1, {:guess, "username3", :a})
    assert to_answer == GenServer.call(:quiz_client, :get_to_guess)
  end

  test "having question to see" do
    GenServer.cast(
      {:global, :quiz_server},
      {:client_send_to_see, "username1", "username2", :a, :a}
    )

    state()
    assert true == GenServer.call(:quiz_client, :get_to_see) |> Map.has_key?("username1")
  end

  @tag :skip
  test "trying to get result after being disconnected" do
    GenServer.call(:quiz_client, :register)
    GenServer.call(:client2, :register)
    GenServer.cast(:client2, {:invite, "client1"})
    GenServer.cast(:client1, {:accept_invitation, "client2"})
    GenServer.cast(:client1, {:answer, "client2", :a})
    GenServer.call(:client2, {:guess, "client1", :a})
    assert :error == GenServer.call(:client1, {:guess, "client2", :a})
  end

  test "user haven't played with anyone yet" do
    assert [] == GenServer.call(:quiz_client, :get_rating)
  end

  test "having rating 100 right after starting game with other user" do
    GenServer.cast({:global, :quiz_server}, {:client_send_invitation, "username1", "username2"})
    GenServer.cast(:quiz_client, {:accept, "username1"})
    assert [{"username1", 100, 100}] == GenServer.call(:quiz_client, :get_rating)
  end

  test "having accurate rating with client" do
    start_game()
    GenServer.cast({:global, :quiz_server}, {:client_send_to_guess, "username1", "username2", :a})
    state()
    true == GenServer.call(:quiz_client, {:guess, "username1", :b})
    state()
    assert {"username1", 0, 100} == GenServer.call(:quiz_client, {:get_rating, "username1"})
  end

  test "having accurate rating" do
    start_game()
    GenServer.cast({:global, :quiz_server}, {:client_send_to_guess, "username1", "username2", :a})
    state()
    true == GenServer.call(:wewquiz_client, {:guess, "username1", :b})
    assert [{"username1", 0, 100}] == GenServer.call(:quiz_client, :get_rating)
  end

  test "listing registered users" do
    assert [] == GenServer.call(:quiz_client, :list_registered) -- ["username1", "username2"]
  end

  test "getting username" do
    assert "username2" == GenServer.call(:quiz_client, :username)
  end

  defp state() do
    :quiz_server
    |> :global.whereis_name()
    |> :sys.get_state()
    |> elem(0)
  end

  def start_game() do
    GenServer.cast({:global, :quiz_server}, {:client_send_invitation, "username1", "username2"})
    state()
    GenServer.cast(:quiz_client, {:accept, "username1"})
  end
end
