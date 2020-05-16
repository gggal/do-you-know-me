defmodule Server.Worker do
  use GenServer

  require Logger
  require Regex

  # alias Server.User
  # alias Server.Invitation

  def user_model, do: Application.get_env(:server, :user)
  def game_model, do: Application.get_env(:server, :game)
  def question_model, do: Application.get_env(:server, :question)
  def invitation_model, do: Application.get_env(:server, :invitation)
  def score_model, do: Application.get_env(:server, :score)

  @questions_count 100

  @moduledoc """
  This module holds and manages information about players and their game state with other players -
  what percentage of other's answers they got right and who's turn it is to play. It associates every
  node with unique username so one's data is safe even if they're disconnected.

  The server's inner state consists of the following data:
    - clients map - all clients, their usernames and if they are online or not
    - relations map - node-specific name for each username and scores for each pair of users that are playing
  """

  @doc """
  Starts the server process.
  """
  def start_link() do
    # GenServer.start_link(__MODULE__, %{}, name: :quiz_server)
    GenServer.start_link(__MODULE__, %{}, name: {:global, :quiz_server})
  end

  @doc """
  Initializes the server.
  """
  def init(args) do
    {:ok, args}
  end

  @doc """
  Called in case a registered client has disconnected.
  """
  def handle_info({:DOWN, _ref, :process, {_, node}, _}, clients) do
    if Map.has_key?(clients, node) do
      {:noreply, Map.delete(clients, node)}
    else
      Logger.error("Monitored client #{node} is not in the online users list.")
      {:noreply, clients}
    end
  end

  @doc """
  Registers new user.
  Returns :taken if the name the user picked is already taken. Returns :already_registered if this
  client is already registered with different name. Returns :ok otherwise.
  """
  def handle_call({:register, user, password}, {from, _}, clients) do
    with :ok <- valid_register_input?(user, from, password, clients) do
      if user_model().insert(user, password) do
        Process.monitor({:quiz_client, node(from)})
        {:reply, :ok, Map.put(clients, node(from), user)}
      else
        {:reply, :db_error, clients}
      end
    else
      {:err, reason} -> {:reply, reason, clients}
    end
  end

  @doc """
  Logs a registered user in. Possible resposnses are:
      :ok - upon success
      :already_logged_in - if this client is already logged in
      :wrong_credentials - if username/password is wrong
  """
  def handle_call({:login, user, password}, {from, _}, clients) do
    with :ok <- valid_login_input?(user, password, from, clients) do

      restore_client_state(user, clients)
      Process.monitor({:quiz_client, node(from)})
      {:reply, :ok, Map.put(clients, node(from), user)}
    else
      {:err, reason} -> {:reply, reason, clients}
    end
  end

  @doc """
  Unregisters registered client. Returns :not_registered if the client hadn't been registered.
  Returns :unregistered otherwise.
  """
  def handle_call({:unregister, password}, {from, _}, clients) do
    with name when not is_nil(name) <- get_username(from, clients) do
      cond do
        not authenticated?(name, password) -> {:reply, :unauthenticated, clients}
        not user_model().delete(name) -> {:reply, :db_error, clients}
        true -> {:reply, :ok, Map.delete(clients, node(from))}
      end
    else
      _ -> {:reply, :not_registered, clients}
    end
  end

  @doc """
   Returns list of all registered clients (connected or dissconnected).
  """
  def handle_call(:list_users, {from, _}, clients) do
    if logged_in?(from, clients) do
      {:reply, {:ok, user_model().all()}, clients}
    else
      {:reply, :unauthenticated, clients}
    end
  end

  @doc """
  Returns a list of all players the client is currently playing with.
  """

  def handle_call(:list_related, {from, _}, clients) do
    if logged_in?(from, clients) do
      {:reply, {:ok, game_model().all_related(get_username(from, clients))}, clients}
    else
      {:reply, :unauthenticated, clients}
    end
  end

  @doc """
  A client `from` is sending an invitation to `to`. If `to` had sent an invitation to `from`, the game
  is assuming that `to` wants to play and an invitation wont be send, instead they will start playing.
  In case `from` or `to` isn't registered or they're already playing nothing is done.
  """

  def handle_call({:invite, to}, {user, _}, clients) do
    with {:ok, from} <- get_valid_username(user, clients),
         :ok <- valid_invite_input?(from, to) do

      res = if invite_helper(from, to, user, clients), do: :ok, else: :db_error
      {:reply, res, clients}
    else
      {:err, reason} -> {:reply, reason, clients}
    end
  end

  @doc """
  Client `from` is accepting `to` 's invitation.
  In case `from` or `to` isn't registered or they're already playing nothing is done.
  """

  def handle_call({:accept, to}, {client, _}, clients) do
    with {:ok, from} <- get_valid_username(client, clients),
         :ok <- valid_accept_decline_input?(from, to) do

      if start_game_helper(from, to, node(client), get_client(clients, to)) do
        {:reply, :ok, clients}
      else
        {:reply, :db_error, clients}
      end
    else
      {:err, reason} -> {:reply, reason, clients}
    end
  end

  @doc """
  Client `from` is declining `to`'s invitation.
  In case `from` or `to` isn't registered or they're already playing nothing is done.
  """

  def handle_call({:decline, to}, {client, _}, clients) do
    with {:ok, from} <- get_valid_username(client, clients),
         :ok <- valid_accept_decline_input?(from, to) do

      res = if invitation_model().delete(to, from), do: :ok, else: :db_error
      {:reply, res, clients}
    else
      {:err, reason} -> {:reply, reason, clients}
    end
  end

  @doc """
  User `from` has answered to a question in a game with `to`. The server sends the same question
  to `to` who has to guess `from`'s answer.
  """

  def handle_call({:answer_question, from, answer}, {client, _}, clients) do
    with {:ok, user} <- get_valid_username(client, clients),
         :ok <- valid_answer_guess_input?(from, user, answer) do

      {:reply, answer_question_helper(from, user, answer, client, clients), clients}
    else
      {:err, reason} -> {:reply, reason, clients}
    end
  end

  @doc """
  User `from` has guessed `to`'s answer correctly. The server sends the same question and `from`'s
   answer to `to` so he/she can see if `from` had guessed and adds the guess to their game state.
  """
  def handle_call({:guess_question, from, guess}, {client, _}, clients) do

    with {:ok, user} <- get_valid_username(client, clients),
         :ok <- valid_answer_guess_input?(from, user, guess) do

      {:reply, guess_question_helper(from, user, guess, clients), clients}
    else
      {:err, reason} -> {:reply, reason, clients}
    end
  end

  @doc """
  Returns {per1, per2} - current game state between `user1` and `user2` where per1 and per2 are the
  according percentages of right guessed questions for every user.
  """
  def handle_call({:get_score, other}, {from, _}, clients) do
    with {:ok, user} <- get_valid_username(from, clients),
          :ok <- valid_score_input?(other, user),
          {:ok, res1} <- get_score_percentage(user, other),
          {:ok, res2} <- get_score_percentage(other, user) do

      {:reply, {:ok, res1, res2}, clients}
    else
      {:err, reason} -> {:reply, reason, clients}
    end
  end

  def questions_count(), do: @questions_count

  # PRIVATE#

  defp get_score_percentage(user, other) do
    with {:ok, score_id} <- game_model().get_score({user, other}, user),
         {:ok, hits} when not is_nil(hits) <- score_model().get_hits(score_id),
         {:ok, misses} when not is_nil(misses) <- score_model().get_misses(score_id) do
      {:ok, Float.round(hits * 100 / (hits + misses), 2)}
    else
      _ -> {:err, :db_error}
    end
  end

  defp guess_question_helper(from, to, guess, clients) do
    with {:ok, old_question} when not is_nil(old_question) <- get_q_number({from, to}, from),
         {:ok, answer} <- get_q_answer({from, to}, from),
         true <- game_model().guess_question({from, to}, from, guess),
         {:ok, guess} <- get_q_guess({from, to}, from) do
      with {:ok, from_client} <- get_client(clients, from) do
        GenServer.cast({:quiz_client, from_client}, {:add_see, to, old_question, answer, guess})
      end

      :ok
    else
      _ -> :db_error
    end
  end

  defp invite_helper(from, to, user, clients) do
    if invitation_model().exists?(to, from) do
      start_game_helper(from, to, node(user), get_client(clients, to))
    else
      invitation_model().insert(from, to)
    end
  end

  defp start_game_helper(from, to, from_client, to_client) do
    if game_model().start(from, to) do
      {:ok, q1} = get_q_number({from, to}, from)
      {:ok, q2} = get_q_number({from, to}, to)
      GenServer.cast({:quiz_client, from_client}, {:add_question, q1, to})

      with {:ok, to_client1} <- to_client do
        GenServer.cast({:quiz_client, to_client1}, {:add_question, q2, from})
      end

      true
    else
      false
    end
  end

  defp answer_question_helper(from, to, answer, client, clients) do
    with {:ok, old_question} <- get_q_number({from, to}, from),
         true <- game_model().answer_question({from, to}, from, answer),
         {:ok, new_question} <- get_q_number({from, to}, from) do
      GenServer.cast({:quiz_client, node(client)}, {:add_question, new_question, from})

      with {:ok, from_client} <- get_client(clients, from) do
        GenServer.cast(
          {:quiz_client, from_client},
          {:add_guess, to, old_question, answer}
        )
      end

      :ok
    else
      _ -> :db_error
    end
  end

  defp restore_client_state(user, client) do
    for other <- invitation_model().get_all_for(user) |> elem(1) do
      GenServer.cast({:quiz_client, client}, {:add_invitation, other})
    end

    for other <- game_model().all_related(user) do
      with {:ok, q1} <- game_model().get_question({user, other}, user),
           {:ok, q2} <- game_model().get_question({user, other}, other),
           {:ok, q1_num} <- question_model().get_number(q1),
           {:ok, q1_answer} <- question_model().get_answer(q1),
           {:ok, q1_guess} <- question_model().get_guess(q1),
           {:ok, q2_num} <- question_model().get_number(q2),
           {:ok, q2_answer} <- question_model().get_answer(q2),
           {:ok, q2_guess} <- question_model().get_guess(q2) do
        if is_nil(q1_answer) do
          GenServer.cast({:quiz_client, client}, {:add_question, q1_num, other})
        end

        if not is_nil(q2_answer) and is_nil(q2_guess) do
          GenServer.cast({:quiz_client, client}, {:add_guess, other, q2_num, q2_answer})
        end

        if not is_nil(q1_answer) and not is_nil(q1_guess) do
          GenServer.cast({:quiz_client, client}, {:add_see, other, q1_num, q1_answer, q1_guess})
        end
      end
    end
  end

  defp valid_register_input?(user, client, password, state) do
    cond do
      logged_in?(client, state) -> {:err, :already_registered}
      username_taken?(user) -> {:err, :taken}
      not valid_username_format?(user) -> {:err, :invalid_username}
      not valid_password_format?(password) -> {:err, :invalid_password}
      true -> :ok
    end
  end

  defp valid_login_input?(user, password, client, state) do
    cond do
      logged_in?(client, state) -> {:err, :already_logged_in}
      not username_taken?(user) -> {:err, :wrong_credentials}
      not authenticated?(user, password) -> {:err, :wrong_credentials}
      true -> :ok
    end
  end


  defp valid_invite_input?(from, to) do
    cond do
      not user_model().exists?(to) -> {:err, :no_such_user}
      # TODO remove ok to impossible or smth
      not possible_to_invite(from, to) -> {:err, :ok}
      true -> :ok
    end
  end

  defp valid_response_format?(response),
    do: is_binary(response) and Regex.match?(~r/^[abc]$/, response)

  def valid_accept_decline_input?(from, to) do
    cond do
      not user_model().exists?(to) -> {:err, :no_such_user}
      not invitation_model().exists?(to, from) -> {:err, :no_such_invitation}
      true -> :ok
    end
  end

  defp valid_answer_guess_input?(from, user, option) do
    cond do
      not user_model().exists?(from) -> {:err, :no_such_user}
      not game_model().exists?(user, from) -> {:err, :no_such_game}
      not valid_response_format?(option) -> {:err, :invalid_response}
      true -> :ok
    end
  end

  defp valid_score_input?(other, user) do
    cond do
      not user_model().exists?(other) -> {:err, :no_such_user}
      not game_model().exists?(other, user) -> {:err, :no_such_game}
      true -> :ok
    end
  end

  defp possible_to_invite(from, to) do
    not game_model().exists?(from, to) and not invitation_model().exists?(from, to) and from != to
  end

  defp get_client(state, user) do
    res = for({k, v} <- state, user == v, do: k)
    if res == [], do: :err, else: {:ok, Enum.at(res, 0)}
  end

  defp get_q_number({user1, user2}, user) do
    with {:ok, q_id} <- game_model().get_question({user1, user2}, user) do
      question_model().get_question_number(q_id)
    else
      _ -> :err
    end
  end

  defp get_q_answer({user1, user2}, user) do
    with {:ok, q_id} <- game_model().get_question({user1, user2}, user) do
      question_model().get_question_answer(q_id)
    else
      _ -> :err
    end
  end

  defp get_q_guess({user1, user2}, user) do
    with {:ok, q_id} <- game_model().get_question({user1, user2}, user) do
      question_model().get_question_guess(q_id)
    else
      _ -> :err
    end
  end

  defp get_username(pid, nodes), do: Map.get(nodes, node(pid), nil)

  defp valid_username_format?(user) do
    Regex.match?(~r/^[[:alnum:]]+$/, user)
  end

  defp valid_password_format?(password) do
    Regex.match?(~r/^.+$/, password)
  end

  defp authenticated?(user, password) do
    user_model().get_password(user) == password
  end

  defp logged_in?(client, all), do: get_username(client, all)
  defp username_taken?(username), do: user_model().exists?(username)

  defp get_valid_username(client, all_clients) do
    if Map.has_key?(all_clients, node(client)) do
      {:ok, Map.get(all_clients, node(client))}
    else
      {:err, :unauthenticated}
    end
  end
end
