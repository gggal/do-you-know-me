defmodule Client.Worker do
  @behaviour Client.Behaviour

  use GenServer
  require Logger
  require Regex

  alias Client.State

  # TODO: client sending invitation/question/guess/answer to themselves

  def server_module, do: Application.get_env(:server, :server_worker)

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

  # __________API__________#

  @doc """
  Registering client. Once registered the client's data will be saved by the server even if the client is
  disconnected. This data is relations with the other players. If `name` id is is already taken by another
  user or this node is associated with another user, registration will fail and :taken will
  be returned. Returns :registered otherwise.
  """
  def register(name, password) do
    Logger.info("Client is registering")
    GenServer.call(:quiz_client, {:register, name, password})
  end

  def login(name, password) do
    Logger.info("Client is logging in")
    GenServer.call(:quiz_client, {:login, name, password})
  end

  @doc """
  Unregistering client. This is the only way client's data can be wiped out. After unregistering a client
  can register again under the same or different name. Returns :not_registered if client is not registered.
  Returns :unregister if the unregistering is successful.
  """
  def unregister(password) do
    Logger.info("Client is unregistering")
    GenServer.call(:quiz_client, {:unregister, password})
  end

  @doc """
  Returns a map with all current invitations.
  """
  def get_invitations() do
    Logger.info("Client is listing invitations")

    GenServer.call(:quiz_client, :get_invitations)
  end

  @doc """
  Obtain one's username.
  """
  def username() do
    Logger.info("Client is fetching their username")

    GenServer.call(:quiz_client, :username)
  end

  @doc """
  Obtain a question to be guessed by the user
  """
  def get_to_guess(other) do
    Logger.info("Client is fetching a question to guess from #{inspect(other)}")

    GenServer.call(:quiz_client, {:get_to_guess, other})
  end

  @doc """
  Obtain a question to be answered by the user
  """
  def get_to_answer(other) do
    GenServer.call(:quiz_client, {:get_to_answer, other})
  end

  @doc """
  Obtain a question to be reviewed by the user
  """
  def get_to_see(other) do
    GenServer.call(:quiz_client, {:get_to_see, other})
  end

  @doc """
  Sends invitation to `user`, doesn't wait for the response.
  """
  def invite(user) do
    Logger.info("Client is inviting #{user}")
    GenServer.call(:quiz_client, {:invite, user})
  end

  @doc """
  Declines an invitation froget_ratingm `from` if it exists.
  """
  def decline(from) do
    Logger.info("Client is declining #{from}'s invitation")
    GenServer.call(:quiz_client, {:decline, from})
  end

  @doc """
  Accepts an invitation from `from` if it exists.
  """
  def accept(from) do
    Logger.info("Client is accepting #{from}'s invitation")
    GenServer.call(:quiz_client, {:accept, from})
  end

  @doc """
  Obtain scores with user `with_user`
  """
  def get_score(with_user) do
    Logger.info("Client is fetching scores with #{with_user}")
    GenServer.call(:quiz_client, {:get_score, with_user})
  end

  @doc """
  List all registered users
  """
  def list_registered() do
    Logger.info("Client is listing all registered clients")
    who_am_i = username()

    with {:ok, list} <- GenServer.call(:quiz_client, :list_registered) do
      {:ok, Enum.filter(list, fn user -> user != who_am_i end)}
    else
      reason -> {:err, reason}
    end
  end

  @doc """
  Lists all users that are playing with the current user
  """
  def list_related() do
    Logger.info("Client is listing all clients they're playing with")
    who_am_i = username()

    with {:ok, list} <- GenServer.call(:quiz_client, :list_related) do
      {:ok, Enum.filter(list, fn user -> user != who_am_i end)}
    else
      reason -> {:err, reason}
    end
  end

  @doc """
  Gives answer to question sent from `other`. Answer should be :a, :b, :c.

  """
  def give_answer(other, answer) do
    Logger.info("Client's answer for #{other}'s question is #{answer}")
    GenServer.call(:quiz_client, {:answer, other, answer})
  end

  @doc """
  Gives guess to question answered from `other`. Answer should be :a, :b, :c.
  """
  def give_guess(other, guess) do
    Logger.info("Client's guess for #{other}'s question is #{guess}")
    GenServer.call(:quiz_client, {:guess, other, guess})
  end

  @impl Client.Behaviour
  def cast_invitation(client, from) do
    GenServer.cast(client, {:add_invitation, from})
  end

  @impl Client.Behaviour
  def cast_to_answer(client, from, q_num) do
    GenServer.cast(client, {:add_question, q_num, from})
  end

  @impl Client.Behaviour
  def cast_to_guess(client, from, q_num, answer) do
    GenServer.cast(client, {:add_guess, from, q_num, answer})
  end

  @impl Client.Behaviour
  def cast_to_see(client, from, q_num, answer, guess) do
    GenServer.cast(client, {:add_result, from, q_num, answer, guess})
  end

  # __________Callbacks__________#

  @doc """
  Starts the server process.
  """
  def start_link() do
    GenServer.start_link(__MODULE__, nil, name: :quiz_client)
  end

  @doc """
  Initializes the server.
  """
  @impl true
  def init(_) do
    {:ok, State.new()}
  end

  @doc """
  Called when the user wants to register under name `username`. Once the user is registered he/she is
  associated with this username and it cannot be changed.
  Returns :taken if `username` is already taken. Retunrs :already_registered if user is already
  registered under different username. Returns :registered otherwise.
  """
  @impl true
  def handle_call({:register, _, _}, _, state = %State{username: name}) when not is_nil(name) do
    {:reply, :already_registered, state}
  end

  def handle_call({:register, username, pass}, _from, state) do
    if valid_password?(pass) and valid_username?(username) do
      {:reply, server_module().register(username, pass), Map.put(state, :username, username)}
    else
      {:reply, :invalid_format, state}
    end
  end

  def handle_call({:login, _, _}, _, state = %State{username: name}) when not is_nil(name) do
    {:reply, :already_registered, state}
  end

  def handle_call({:login, username, pass}, _from, state) do
    if valid_password?(pass) and valid_username?(username) do
      {:reply, server_module().login(username, pass), Map.put(state, :username, username)}
    else
      {:reply, :invalid_format, state}
    end
  end

  @doc """
  Called when the user wants to unregister. Returns :not_registered if the client hadn't been registered.
  Returns :unregistered otherwise.
  """
  def handle_call({:unregister, _pass}, _, state = %State{username: nil}) do
    {:reply, :not_registered, state}
  end

  def handle_call({:unregister, pass}, _from, _state) do
    {:reply, server_module().unregister(pass), State.new()}
  end

  @doc """
  Returns map of all invitations sent from other clients.
  """
  def handle_call(:get_invitations, _, state) do
    {:reply, State.get_invitations(state), state}
  end

  @doc """
  Returns client's username if they're registered.
  """
  def handle_call(:username, _from, state) do
    {:reply, State.get_username(state), state}
  end

  @doc """
  If `from` is a registered user, returns {question, a, b, c} where a,b and c are the possible answer.
  Returns :error otherwise.
  """
  def handle_call({:get_to_guess, other_user}, _, state) do
    with {q_num, q_answer} <- State.get_to_guess(state, other_user),
         {:ok, question} <- fetch_question(q_num) do
      {:reply, {:ok, {question, q_answer}}, state}
    else
      nil ->
        {:reply, {:err, :no_such_question}, state}

      {:error, reason} ->
        Logger.error(
          "Fetching a question failed while getting a question to guess. Reason: #{
            inspect(reason)
          }"
        )

        {:reply, {:err, reason}, state}

      received ->
        Logger.error(
          "Getting a question to guess failed. Received invalid format from server: #{
            inspect(received)
          }"
        )

        {:reply, {:err, :invalid_format}, state}
    end
  end

  @doc """
  If `from` is a registered user, returns {question, a, b, c} where a,b and c are the possible answer.
  Returns :error otherwise.
  """
  def handle_call({:get_to_answer, other_user}, _, state) do
    with q_num when is_integer(q_num) <- State.get_to_answer(state, other_user),
         {:ok, question} <- fetch_question(q_num) do
      {:reply, {:ok, question}, state}
    else
      nil ->
        {:reply, {:err, :no_such_question}, state}

      {:error, reason} ->
        Logger.error(
          "Getting a question to answer failed. Received invalid format from server: #{
            inspect(reason)
          }"
        )

        {:reply, {:err, reason}, state}

      received ->
        Logger.error(
          "Fetching a question failed while getting a question to answer. Received invalid format from server: #{
            inspect(received)
          }"
        )

        {:reply, {:err, :invalid_format}, state}
    end
  end

  @doc """
  If `from` is a registered user, returns {question, your_answer, others_guess}.
  Returns :error otherwise.
  """
  def handle_call({:get_to_see, other_user}, _, state) do
    with {q_num, q_ans, q_guess} <- State.get_to_see(state, other_user),
         {:ok, question} <- fetch_question(q_num) do
      {:reply, {:ok, {question, q_ans, q_guess}}, state}
    else
      nil ->
        {:reply, {:err, :no_such_question}, state}

      {:error, reason} ->
        Logger.error(
          "Getting a question to see failed. Received invalid format from server: #{
            inspect(reason)
          }"
        )

        {:reply, {:err, reason}, state}

      received ->
        Logger.error(
          "Fetching a question failed while getting a question to see. Received invalid format from server: #{
            inspect(received)
          }"
        )

        {:reply, {:err, :invalid_format}, state}
    end
  end

  @doc """
  Returns {per1, per2} - current game state between `user1` and `user2` where per1 and per2 are the
  according percentages of right guessed questions for every user.
  """
  def handle_call({:get_score, with_other}, _, state) do
    {:reply, server_module().get_score(with_other), state}
  end

  @doc """
  Returns list of all registered clients
  """
  def handle_call(:list_registered, _, state) do
    {:reply, server_module().list_users(), state}
  end

  def handle_call(:list_related, _, state) do
    {:reply, server_module().list_related(), state}
  end

  @doc """
  Returns true if the client has given correct answer.
  Returns false if the client has g2iven wrong answer.
  Returns :error if `from` is not registered or `guess` is not :a, :b or :c.
  """
  def handle_call({:guess, from, guess}, _, state)
      when guess == "a" or guess == "b" or guess == "c" do
    case State.get_to_guess(state, from) do
      nil ->
        {:reply, {:err, :no_such_question}, state}

      {_, answer} ->
        Logger.info("Guess is #{guess} and the right answer is #{answer}")

        with :ok <- server_module().guess_question(from, guess) do
          {:reply, {:ok, answer == guess}, State.remove_to_guess(state, from)}
        else
          reason -> {:reply, {:err, reason}, state}
        end
    end
  end

  def handle_call({:guess, _, _}, _, state) do
    {:reply, {:err, :invalid_format}, state}
  end

  @doc """
  If answer is :a, :b or :c and to is name the client is currently playing with, sends the answer
  to server.
  """
  def handle_call({:answer, from, answer}, _, state)
      when answer == "a" or answer == "b" or answer == "c" do
    case State.get_to_answer(state, from) do
      nil ->
        {:reply, {:err, :no_such_question}, state}

      _ ->
        with :ok <- server_module().answer_question(from, answer) do
          {:reply, :ok, State.remove_to_answer(state, from)}
        else
          reason -> {:reply, {:err, reason}, state}
        end
    end
  end

  def handle_call({:answer, _, _}, _, state) do
    {:reply, {:err, :invalid_format}, state}
  end

  @doc """
  Called when user wants to start new game with `to`.
  """
  def handle_call({:invite, to}, _, state) do
    {:reply, server_module().invite(to), state}
  end

  @doc """
  Called when user has received an invitation from `from` and wants accept it.
  """
  def handle_call({:accept, from}, _, state) do
    if from in State.get_invitations(state) do
      with :ok <- server_module().accept(from) do
        {:reply, :ok, State.remove_invitation(state, from)}
      else
        reason -> {:reply, {:err, reason}, state}
      end
    else
      {:reply, {:err, :no_such_user}, state}
    end
  end

  @doc """
  Called when user has received an invitation from `from` and wants decline it.
  """
  def handle_call({:decline, from}, _, state) do
    if from in State.get_invitations(state) do
      with :ok <- server_module().decline(from) do
        {:reply, :ok, State.remove_invitation(state, from)}
      else
        reason -> {:reply, {:err, reason}, state}
      end
    else
      {:reply, {:err, :no_such_user}, state}
    end
  end


  @doc """
  Called when server sends question for user to answer.
  """
  @impl true
  def handle_cast({:add_question, q, from}, state) do
    {:noreply, State.put_to_answer(state, from, q)}
  end

  @doc """
  Called when server sends question for user to guess.
  """
  def handle_cast({:add_guess, from, question, ans}, state) do
    {:noreply, State.put_to_guess(state, from, {question, ans})}
  end

  @doc """
  Called when server sends question that another user tried to guess.
  """
  def handle_cast({:add_result, from, question, ans, guess}, state) do
    {:noreply, State.put_to_see(state, from, {question, ans, guess})}
  end

  @doc """
  Called when `from` wants to start new game.
  """
  def handle_cast({:add_invitation, from}, state) do
    {:noreply, State.add_invitation(state, from)}
  end

  # PRIVATE#

  defp fetch_question(question_number) when is_integer(question_number) do
    try do
      {:ok, line} =
        File.stream!(@questions_file)
        |> Enum.at(question_number - 1)
        |> Poison.decode()

      {:ok, List.to_tuple(line)}
    rescue
      File.Error ->
        {:error, :cannot_open_questions_file}

      MatchError ->
        {:error, :corrupted_questions_file}

      _ ->
        {:error, :unknown}
    end

    # |> Formatter.info(label: "Fetching question No#{question_number}: ")
  end

  defp fetch_question(_invalid_value) do
    {:error, :invalid_format}
  end

  def valid_username?(name) when is_binary(name), do: Regex.match?(~r/^.+$/, name)
  def valid_username?(_), do: false
  def valid_password?(name) when is_binary(name), do: Regex.match?(~r/^.+$/, name)
  def valid_password?(_), do: false
end
