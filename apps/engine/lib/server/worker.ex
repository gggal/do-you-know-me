defmodule Server.Worker do
  @behaviour Server.Behaviour

  use GenServer

  require Logger
  require Regex

  alias Server.State

  def user_model, do: Application.get_env(:engine, :user)
  def game_model, do: Application.get_env(:engine, :game)
  def question_model, do: Application.get_env(:engine, :question)
  def invitation_model, do: Application.get_env(:engine, :invitation)
  def score_model, do: Application.get_env(:engine, :score)

  def client_module, do: Application.get_env(:engine, :client)

  @questions_count 100

  @moduledoc """
  This module holds and manages information about players and their game state with
  other players - invitations, scores, questions, answers, guesses and who's turn it
  is to play. This data is being persisted in a database.

  The server's inner state consists of users and clients - clients are the nodes
  from which users can log in. A user can be logged-in from mulitple clients at a time,
  but a client can only have one user associated with it.
  """

  # __________API__________#

  @doc """
  Registers and logs in a new user. Possible responses are:
    :taken - if the name the user picked is already taken
    :already_registered - if this client is already associated with another user
    :db_error - if the user cannot be registered due to internal db error
    :ok - if the user gets registered successfully
  """
  @impl Server.Behaviour
  def register(user, password) do
    GenServer.call(self_pid(), {:register, user, password})
  end

  @doc """
  Logs in a registered user. Possible responses are:
    :already_logged_in - if this client is already logged in
    :wrong_credentials - if username/password is wrong
    :ok - upon success
  """
  @impl Server.Behaviour
  def login(user, password) do
    GenServer.call(self_pid(), {:login, user, password})
  end

  @doc """
  Unregisters registered client. Possible responses are:
    :unauthenticated - if the client hadn't been logged in
    :db_error - if the user cannot be unregistered due to internal db error
    :ok - if the user has been unregistered successffully
  """
  @impl Server.Behaviour
  def unregister(password) do
    GenServer.call(self_pid(), {:unregister, password})
  end

  @doc """
  Lists all users (online or not). Possible responses are:
    :unauthenticated - if the client hadn't been logged in
    :{ok, list} - otherwise
  """
  @impl Server.Behaviour
  def list_users() do
    GenServer.call(self_pid(), :list_users)
  end

  @doc """
  The user is sending invitation to user `to`. If `to` had previously sent an
  invitation to the user, the game assumes that they both want to play and an
  invitation wont be send, instead they will start playing. Possible responses are:
    :unauthenticated - if the client hadn't been logged in
    :no_such_user - if user `to` doesn't exist
    :db_error - internal db error occurred
    :not_eligible - if the user tries to invite themselves or to invite someone
  who they're already playing with/invited
    :ok- invitation sent successfully
  """
  @impl Server.Behaviour
  def invite(to) do
    GenServer.call(self_pid(), {:invite, to})
  end

  @doc """
  The user is accepting `to` 's invitation. Possible responses are:
    :unauthenticated - if the client hadn't been logged in
    :no_such_user - if user `to` doesn't exist
    :no_such_invitation - if `to` hadn't invited the user
    :db_error - internal db error occurred
    :ok - the invitation was accepted successfully
  """
  @impl Server.Behaviour
  def accept(to) do
    GenServer.call(self_pid(), {:accept, to})
  end

  @doc """
  The user is declining `to` 's invitation. Possible responses are:
    :unauthenticated - if the client hadn't been logged in
    :no_such_user - if user `to` doesn't exist
    :no_such_invitation - if `to` hadn't invited the user
    :db_error - internal db error occurred
    :ok - the invitation was declined successfully
  """
  @impl Server.Behaviour
  def decline(to) do
    GenServer.call(self_pid(), {:decline, to})
  end

  @doc """
  The user is answering a question from `from` and their answer is `answer`. If the
  server accepts the answer, a new question is sent to the user and the current
  question is sent to `from` to guess. Possible responses are:
    :unauthenticated - if the client hadn't been logged in
    :no_such_user - if user `from` doesn't exist
    :no_such_game - if there's no game for these users
    :db_error - internal db error occurred
    :invalid_response - `answer`'s format is incorrect
    :ok - the question was answered successfully
  """
  @impl Server.Behaviour
  def answer_question(from, answer) do
    GenServer.call(self_pid(), {:answer_question, from, answer})
  end

  @doc """
  The user is guessing `from`'s answer and their guess is `guess`. If the
  server accepts the guess, it's sent to `from`. Possible responses are:
    :unauthenticated - if the client hadn't been logged in
    :no_such_user - if user `from` doesn't exist
    :no_such_game - if there's no game for these users
    :db_error - internal db error occurred
    :invalid_response - `guess`'s format is incorrect
    :ok - the answer was guessed successfully
  """
  @impl Server.Behaviour
  def guess_question(from, guess) do
    GenServer.call(self_pid(), {:guess_question, from, guess})
  end

  @doc """
  The user is fetching their score with `other`. Scores are decimal numbers that
  represent guess success rate. Possible responses are:
    :unauthenticated - if the client hadn't been logged in
    :no_such_user - if user `from` doesn't exist
    :no_such_game - if there's no game for these users
    :db_error - internal db error occurred
    {:ok, score1, score2} - score1 is the user's score and score2 is `other`'s score
  """
  @impl Server.Behaviour
  def get_score(other) do
    GenServer.call(self_pid(), {:get_score, other})
  end

  @doc """
  The user is checking if it is their turn to play with `other`.
  Possible responses are:
    :unauthenticated - if the client hadn't been logged in
    :no_such_user - if user `from` doesn't exist
    :no_such_game - if there's no game for these users
    :db_error - internal db error occurred
    {:ok, turn} - true if it's user's turn to play, false otherwise
  """
  @impl Server.Behaviour
  def get_turn(other) do
    GenServer.call(self_pid(), {:get_turn, other})
  end

  # __________Callbacks__________#

  @doc """
  Starts the server process.
  """
  def start_link() do
    GenServer.start_link(__MODULE__, State.new(), name: {:global, :dykm_server})
  end

  @doc """
  Initializes the server.
  """
  @impl true
  def init(args) do
    {:ok, args}
  end

  @doc """
  Called in case a client has disconnected. If the client is the user's last client,
  the user gets removed from the online users list.
  """
  @impl true
  def handle_info({:DOWN, _ref, :process, {_, node}, _}, state) do
    if State.contains_client?(state, node) do
      {:noreply, State.delete_client(state, node)}
    else
      Logger.error("Monitored client #{node} is not in the online users list.")
      {:noreply, state}
    end
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  @impl true
  def handle_call({:register, user, password}, {client_pid, _}, state) do
    with :ok <- valid_register_input?(user, client_pid, password, state) do
      if user_model().insert(user, password) do
        Process.monitor({:dykm_client, node(client_pid)})
        {:reply, :ok, State.add(state, user, node(client_pid))}
      else
        {:reply, :db_error, state}
      end
    else
      {:err, reason} -> {:reply, reason, state}
    end
  end

  def handle_call({:login, user, password}, {client_pid, _}, state) do
    with :ok <- valid_login_input?(user, password, client_pid, state) do
      state = State.add(state, user, node(client_pid))
      restore_client_state(user, state)
      Process.monitor({:dykm_client, node(client_pid)})
      {:reply, :ok, state}
    else
      {:err, reason} -> {:reply, reason, state}
    end
  end

  def handle_call({:unregister, password}, {client_pid, _}, state) do
    with {:ok, name} <- get_valid_username(client_pid, state) do
      cond do
        not authenticated?(name, password) -> {:reply, :unauthenticated, state}
        not user_model().delete(name) -> {:reply, :db_error, state}
        true -> {:reply, :ok, State.delete(state, name)}
      end
    else
      _ -> {:reply, :unauthenticated, state}
    end
  end

  def handle_call(:list_users, {client_pid, _}, state) do
    if logged_in?(client_pid, state) do
      {:reply, {:ok, user_model().all()}, state}
    else
      {:reply, :unauthenticated, state}
    end
  end

  def handle_call({:invite, to}, {client_pid, _}, state) do
    with {:ok, from} <- get_valid_username(client_pid, state),
         :ok <- valid_invite_input?(from, to) do
      res = if invite_helper(from, to, state), do: :ok, else: :db_error
      {:reply, res, state}
    else
      {:err, reason} -> {:reply, reason, state}
    end
  end

  def handle_call({:accept, to}, {client_pid, _}, state) do
    with {:ok, from} <- get_valid_username(client_pid, state),
         :ok <- valid_accept_decline_input?(from, to) do
      if start_game_helper(to, from, state) do
        {:reply, :ok, state}
      else
        {:reply, :db_error, state}
      end
    else
      {:err, reason} -> {:reply, reason, state}
    end
  end

  def handle_call({:decline, to}, {client_pid, _}, state) do
    with {:ok, from} <- get_valid_username(client_pid, state),
         :ok <- valid_accept_decline_input?(from, to) do
      res = if invitation_model().delete(to, from), do: :ok, else: :db_error
      {:reply, res, state}
    else
      {:err, reason} -> {:reply, reason, state}
    end
  end

  def handle_call({:answer_question, from, answer}, {client_pid, _}, state) do
    with {:ok, user} <- get_valid_username(client_pid, state),
         :ok <- valid_answer_guess_input?(from, user, answer) do
      {:reply, answer_question_helper(from, user, answer, state), state}
    else
      {:err, reason} -> {:reply, reason, state}
    end
  end

  def handle_call({:guess_question, from, guess}, {client_pid, _}, state) do
    with {:ok, user} <- get_valid_username(client_pid, state),
         :ok <- valid_answer_guess_input?(from, user, guess) do
      {:reply, guess_question_helper(from, user, guess, state), state}
    else
      {:err, reason} -> {:reply, reason, state}
    end
  end

  def handle_call({:get_score, other}, {client_pid, _}, state) do
    with {:ok, user} <- get_valid_username(client_pid, state),
         :ok <- valid_score_turn_input?(other, user),
         {:ok, res1} <- get_score_percentage(user, other),
         {:ok, res2} <- get_score_percentage(other, user) do
      {:reply, {:ok, res1, res2}, state}
    else
      {:err, reason} -> {:reply, reason, state}
    end
  end

  def handle_call({:get_turn, other}, {client_pid, _}, state) do
    with {:ok, user} <- get_valid_username(client_pid, state),
         :ok <- valid_score_turn_input?(other, user),
         {:ok, next_to_play} <- game_model().get_turn(user, other) do
      {:reply, {:ok, next_to_play == user}, state}
    else
      {:err, reason} ->
        {:reply, reason, state}

      :err ->
        # get_turn failed -> db is in inconsistent state
        {:reply, :db_error, state}
    end
  end

  def questions_count(), do: @questions_count

  # __________Private functions__________#

  defp get_score_percentage(user, other) do
    with {:ok, score_id} <- game_model().get_score({user, other}, user),
         {:ok, hits} when not is_nil(hits) <- score_model().get_hits(score_id),
         {:ok, misses} when not is_nil(misses) <- score_model().get_misses(score_id) do
      if hits + misses > 0 do
        {:ok, Float.round(hits * 100 / (hits + misses), 2)}
      else
        {:ok, 0.00}
      end
    else
      _ -> {:err, :db_error}
    end
  end

  defp guess_question_helper(from, to, guess, state) do
    with {:ok, old_question} when not is_nil(old_question) <- get_q_number({from, to}, from),
         {:ok, q_id} <- game_model().get_old_question({from, to}, from),
         {:ok, answer} <- question_model().get_question_answer(q_id),
         true <- game_model().guess_question({from, to}, from, guess) do
      send_user(from, state, :cast_to_see, [to, old_question, answer, guess])

      :ok
    else
      _ -> :db_error
    end
  end

  defp invite_helper(from, to, state) do
    if invitation_model().exists?(to, from) do
      start_game_helper(to, from, state)
    else
      send_user(to, state, :cast_invitation, [from])
      invitation_model().insert(from, to)
    end
  end

  defp start_game_helper(from, to, state) do
    if game_model().start(from, to, to) do
      with {:ok, q1} <- get_new_q_number({from, to}, from),
           {:ok, q2} <- get_new_q_number({from, to}, to) do
        send_user(from, state, :cast_to_answer, [to, q1])
        send_user(to, state, :cast_to_answer, [from, q2])
        true
      else
        _ -> false
      end
    else
      false
    end
  end

  defp answer_question_helper(from, to, answer, state) do
    with {:ok, prev_question} <- get_new_q_number({from, to}, to),
         true <- game_model().answer_question({from, to}, to, answer),
         {:ok, new_question} <- get_new_q_number({from, to}, to) do
      send_user(to, state, :cast_to_answer, [from, new_question])
      send_user(from, state, :cast_to_guess, [to, prev_question, answer])

      :ok
    else
      _ -> :db_error
    end
  end

  defp restore_client_state(user, state) do
    for other <- invitation_model().get_all_for(user) |> elem(1) do
      send_user(user, state, :cast_invitation, [other])
    end

    for other <- game_model().all_related(user) do
      with {:ok, new_q1} <- game_model().get_question({user, other}, user),
           {:ok, q1} <- game_model().get_old_question({user, other}, user),
           {:ok, q2} <- game_model().get_old_question({user, other}, other),
           {:ok, new_q1_num} <- question_model().get_question_number(new_q1),
           {:ok, q1_num} <- question_model().get_question_number(q1),
           {:ok, q1_answer} <- question_model().get_question_answer(q1),
           {:ok, q1_guess} <- question_model().get_question_guess(q1),
           {:ok, q2_num} <- question_model().get_question_number(q2),
           {:ok, q2_answer} <- question_model().get_question_answer(q2),
           {:ok, q2_guess} <- question_model().get_question_guess(q2) do
        if not is_nil(new_q1_num) do
          send_user(user, state, :cast_to_answer, [other, new_q1_num])
        end

        if not is_nil(q2_answer) and is_nil(q2_guess) do
          send_user(user, state, :cast_to_guess, [other, q2_num, q2_answer])
        end

        if not is_nil(q1_answer) and not is_nil(q1_guess) do
          send_user(user, state, :cast_to_see, [other, q1_num, q1_answer, q1_guess])
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
      not possible_to_invite?(from, to) -> {:err, :not_eligible}
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

  defp valid_score_turn_input?(other, user) do
    cond do
      not user_model().exists?(other) -> {:err, :no_such_user}
      not game_model().exists?(other, user) -> {:err, :no_such_game}
      true -> :ok
    end
  end

  defp possible_to_invite?(from, to) do
    not game_model().exists?(from, to) and
      not invitation_model().exists?(from, to) and
      from != to
  end

  defp get_q_number({user1, user2}, user) do
    with {:ok, q_id} <- game_model().get_old_question({user1, user2}, user) do
      question_model().get_question_number(q_id)
    else
      _ -> :err
    end
  end

  defp get_new_q_number({user1, user2}, user) do
    with {:ok, q_id} <- game_model().get_question({user1, user2}, user) do
      question_model().get_question_number(q_id)
    else
      _ -> :err
    end
  end

  defp valid_username_format?(user) do
    Regex.match?(~r/^[[:alnum:]]+$/, user)
  end

  defp valid_password_format?(password) do
    Regex.match?(~r/^.+$/, password)
  end

  defp authenticated?(user, password) do
    with {:ok, db_pass} <- user_model().get_password(user) do
      db_pass == password
    else
      nil -> false
    end
  end

  defp logged_in?(client_pid, state) do
    State.contains_client?(state, node(client_pid))
  end

  defp username_taken?(username), do: user_model().exists?(username)

  defp get_valid_username(pid, state) do
    if State.contains_client?(state, node(pid)) do
      {:ok, State.get_user(state, node(pid))}
    else
      {:err, :unauthenticated}
    end
  end

  defp send_user(user, state, function, arguments) do
    for client <- State.get_clients(state, user) do
      apply(client_module(), function, [client] ++ arguments)
    end
  end

  # the pid of this genserver
  defp self_pid, do: :global.whereis_name(:dykm_server)
end
