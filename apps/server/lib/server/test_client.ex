defmodule Server.TestClient do
  use GenServer
  require Logger

  @server_name Application.get_env(:client, :server_name, :quiz_server)

  def start_link() do
    Logger.debug("Starting test client.")
    GenServer.start_link(__MODULE__, nil, name: :quiz_client)
  end

  def init(_) do
    {:ok, %{}}
  end

  def handle_call({:register, username}, _from, state) do
    {:reply, GenServer.call({:global, :quiz_server}, {:register, username}),
     Map.put(state, :username, username)}
  end

  def handle_call(:unregister, _from, state) do
    {:reply, GenServer.call({:global, :quiz_server}, :unregister), state}
  end

  def handle_call({:guess, :right, from, guess}, _, %{username: to} = state)
      when guess == :a or guess == :b or guess == :c do
    GenServer.cast({:global, @server_name}, {:guess, from, to, 0, guess, guess})
    {:reply, true, state}
  end

  def handle_call({:guess, :wrong, from, guess}, _, %{username: to} = state) when guess == :a do
    GenServer.cast({:global, @server_name}, {:guess, from, to, 0, guess, :b})
    {:reply, false, state}
  end

  def handle_call({:guess, :wrong, from, guess}, _, %{username: to} = state) when guess == :b do
    GenServer.cast({:global, @server_name}, {:guess, from, to, 0, guess, :c})
    {:reply, false, state}
  end

  def handle_call({:guess, :wrong, from, guess}, _, %{username: to} = state) when guess == :c do
    GenServer.cast({:global, @server_name}, {:guess, from, to, 0, guess, :a})
    {:reply, false, state}
  end

  def handle_call({:guess, _, _}, _, state) do
    {:reply, :error, state}
  end

  def handle_call(:get_rating, _, state) do
    {:reply, GenServer.call({:global, @server_name}, :get_rating), state}
  end

  def handle_call({:get_rating, with}, _, state) do
    {:reply, GenServer.call({:global, @server_name}, {:get_rating, with}), state}
  end

  def handle_call(:list_registered, _, state) do
    {:reply, GenServer.call({:global, @server_name}, :list_registered), state}
  end

  def handle_cast({:answer, to, answer}, %{username: from} = state) do
    GenServer.cast({:global, @server_name}, {:answer, from, to, answer, ""})
    {:noreply, state}
  end

  def handle_cast({:invite, to}, %{username: username} = state) do
    GenServer.cast({:global, @server_name}, {:invitation, username, to})
    {:noreply, state}
  end

  def handle_cast({:accept, from}, %{username: username} = state) do
    GenServer.cast({:global, @server_name}, {:accept, username, from})
    {:noreply, state}
  end

  def handle_cast({:decline, from}, %{username: username} = state) do
    GenServer.cast({:global, @server_name}, {:decline, username, from})
    {:noreply, state}
  end

  def handle_cast({:add_question, _, _}, state) do
    {:noreply, state}
  end

  def handle_cast({:add_guess, _, _, _}, state) do
    {:noreply, state}
  end

  def handle_cast({:add_result, _, _, _, _}, state) do
    {:noreply, state}
  end

  def handle_cast({:add_invitation, _}, state) do
    {:noreply, state}
  end
end
