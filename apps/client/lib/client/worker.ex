defmodule Client.Worker do
  use GenServer
  require Logger
  # TODO: client sending invitation/question/guess/answer to themselves

  @server_name Application.get_env(:client, :server_name, :quiz_server)
  @server_location Application.get_env(:client, :server_location, "127.0.0.1")
  @questions_file "questions.txt"

  @moduledoc """
  This module holds user's name after they are registered, all invitations sent from other users,
  all the questions they have to answer, all the questions others answered and their guesses,
  all the questions user had answered and if other's got them right. A user can only register once
  and the username cannot be changed.

  The client's inner state consists of the following data:
    - client's username
    - to_guess - all questions waiting to be guessed, the correct answer, the question and other
    client's username
    - to_answer - all questions waiting to be answered, the question and other client's username
    - to_see - all guessed questions, the guess, the correct answer, the question and other
    client's username
  """

  @doc """
  Starts the server process.
  """
  def start_link() do
    GenServer.start_link(__MODULE__, nil, name: :quiz_client)
  end

  @doc """
  Initializes the server.
  """
  def init(_) do
    {:ok, %{invitations: %{}, to_answer: %{}, to_guess: %{}, to_see: %{}}}
  end

  @doc """
  Called when the user wants to register under name `username`. Once the user is registered he/she is
  associated with this username and it cannot be changed.
  Returns :taken if `username` is already taken. Retunrs :already_registered if user is already
  registered under different username. Returns :registered otherwise.
  """
  def handle_call({:register, username}, _from, state) do
    {:reply, GenServer.call({:global, :quiz_server}, {:register, username}),
     Map.put(state, :username, username)}
  end

  @doc """
  Called when the user wants to unregister. Returns :not_registered if the client hadn't been registered.
  Returns :unregistered otherwise.
  """
  def handle_call(:unregister, _from, state) do
    {:reply, GenServer.call({:global, :quiz_server}, :unregister), state}
  end

  @doc """
  Returns client's username if they're registered.
  """
  def handle_call(:username, _from, %{username: username} = state) do
    {:reply, username, state}
  end

  def handle_call(:username, _from, state) do
    {:reply, :error, state}
  end

  @doc """
  If `from` is a registered user, returns {question, a, b, c} where a,b and c are the possible answer.
  Returns :error otherwise.
  """
  def handle_call(:get_to_guess, _, %{to_guess: questions} = state) do
    {:reply,
     questions
     |> Enum.map(fn {user, {q, _ans}} -> {user, {fetch_question(q)}} end)
     |> Map.new(), state}
  end

  @doc """
  If `from` is a registered user, returns {question, a, b, c} where a,b and c are the possible answer.
  Returns :error otherwise.
  """
  def handle_call(:get_to_answer, _, %{to_answer: questions} = state) do
    Formatter.info(questions, label: "Questions")
    # Logger.warn(questions)
    {:reply,
     questions
     |> Enum.map(fn {user, q} -> {user, fetch_question(q)} end)
    #  |> Formatter.info(label: "Debug: ")
     |> Map.new(), state}
  end

  @doc """
  If `from` is a registered user, returns {question, your_answer, others_guess}.
  Returns :error otherwise.
  """
  def handle_call(:get_to_see, _, %{to_see: questions} = state) do
    {:reply,
     questions
     |> Enum.map(fn {user, {q, ans, guess}} -> {user, {fetch_question(q), ans, guess}} end)
     |> Map.new(), Map.delete(state, :to_see)}
  end

  @doc """
  Returns list of tuples {other, per1, per2} - current game states between /user1 and everyone that
  he/she is playing with. `other` is the username of the other user, `per1` and `per2` are the
  percentages of right guessed questions for every user.
  """
  def handle_call(:get_rating, _, state) do
    {:reply, GenServer.call({:global, @server_name}, :get_rating), state}
  end

  @doc """
  Returns {per1, per2} - current game state between `user1` and `user2` where per1 and per2 are the
  according percentages of right guessed questions for every user.
  """
  def handle_call({:get_rating, with}, _, state) do
    {:reply, GenServer.call({:global, @server_name}, {:get_rating, with}), state}
  end

  @doc """
  Returns map of all invitations sent from other clients.
  """
  # TODO get_invitations
  def handle_call(:see_invitations, _, %{invitations: invitations} = state) do
    {:reply, invitations, state}
  end

  def handle_call(:see_invitations, _, state) do
    {:reply, :error, state}
  end

  @doc """
  Returns list of all registered clients
  """
  def handle_call(:list_registered, _, state) do
    {:reply, GenServer.call({:global, @server_name}, :list_registered), state}
  end

  @doc """
  Returns true if the client has given correct answer.
  Returns false if the client has given wrong answer.
  Returns :error if `from` is not registered or `guess` is not :a, :b or :c.
  """
  def handle_call({:guess, from, guess}, _, %{username: name, to_guess: guess_map} = state)
      when guess == :a or guess == :b or guess == :c do
    case Map.get(guess_map, from) do
      nil ->
        {:reply, :error, state}

      {q, ^guess} ->
        GenServer.cast({:global, @server_name}, {:guess, name, from, q, guess, guess})
        {:reply, true, %{state | to_guess: Map.delete(guess_map, from)}}

      {q, ans} ->
        GenServer.cast({:global, @server_name}, {:guess, name, from, q, guess, ans})
        {:reply, false, %{state | to_guess: Map.delete(guess_map, from)}}
    end
  end

  def handle_call({:guess, _, _}, _, state) do
    {:reply, :error, state}
  end

  @doc """
  If answer is :a, :b or :c and to is name the client is currently playing with, sends the answer
  to server.
  """
  def handle_cast({:answer, to, answer}, %{username: from, to_answer: q_map} = state)
      when answer == :a or answer == :b or answer == :c do
    case Map.get(q_map, to) do
      nil ->
        {:noreply, state}

      q ->
        GenServer.cast({:global, @server_name}, {:answer, from, to, q, answer})
        {:noreply, %{state | to_answer: Map.delete(q_map, to)}}
    end
  end

  def handle_cast({:answer, _, _}, state) do
    {:noreply, state}
  end

  @doc """
  Called when server sends question for user to answer.
  """
  def handle_cast({:add_question, q, from}, %{to_answer: qs} = state) do
    Logger.warn("Server sends question #{q}, #{Enum.count(qs)}")
    {:noreply, %{state | to_answer: Map.put(qs, from, q)}}
  end

  @doc """
  Called when server sends question for user to guess.
  """
  def handle_cast({:add_guess, from, question, ans}, %{to_guess: gs} = state) do
    {:noreply, %{state | to_guess: Map.put(gs, from, {question, ans})}}
  end

  @doc """
  Called when server sends question that another user tried to guess.
  """
  def handle_cast({:add_result, from, question, ans, guess}, %{to_see: rs} = state) do
    {:noreply, %{state | to_see: Map.put(rs, from, {question, ans, guess})}}
  end

  @doc """
  Called when `from` wants to start new game.
  """
  def handle_cast({:add_invitation, from}, %{invitations: is} = state) do
    {:noreply, %{state | invitations: Map.put(is, from, true)}}
  end

  @doc """
  Called when user wants to start new game with `to`.
  """
  def handle_cast({:invite, to}, %{username: username} = state) do
    GenServer.cast({:global, @server_name}, {:invitation, username, to})
    {:noreply, state}
  end

  @doc """
  Called when user has received an invitation from `from` and wants accept it.
  """
  def handle_cast({:accept, from}, %{username: username, invitations: invitations} = state) do
    GenServer.cast({:global, @server_name}, {:accept, username, from})
    {:noreply, %{state | invitations: Map.delete(invitations, from)}}
  end

  @doc """
  Called when user has received an invitation from `from` and wants decline it.
  """
  def handle_cast({:decline, from}, %{username: username, invitations: invitations} = state) do
    GenServer.cast({:global, @server_name}, {:decline, username, from})
    {:noreply, %{state | invitations: Map.delete(invitations, from)}}
  end

  # PRIVATE#

  def fetch_question(question_number) do

    File.stream!(@questions_file)
    |> Enum.at(question_number - 1)
    |> Poison.decode()
    |> elem(1)
    |> List.to_tuple()
    |> Formatter.info(label: "Fetching question No#{question_number}: ")
  end
end
