defmodule Client.Worker do
  @behaviour Client.Behaviour

  use GenServer
  require Logger
  require Regex

  alias Client.State

  # TODO: client sending invitation/question/guess/answer to themselves

  def server_module, do: Application.get_env(:engine, :server_worker)

  @questions_file "questions.txt"

  @type question :: {String.t(), String.t(), String.t(), String.t()}

  @moduledoc """
  This module holds user's name after they are registered, all invitations sent from other
   users, all the questions they have to answer, all the questions others answered and
  their guesses, all the questions user had answered and if other's got them right.

  The client's inner state consists of the following data:
    - client's username
    - to_guess - all questions waiting to be guessed, the correct answer, the question and
     other client's username
    - to_answer - all questions waiting to be answered, the question and other client's username
    - to_see - all guessed questions, the guess, the correct answer, the question and other
    client's username

  The API described below is intended to be used by both UI applications and the server
  itself.

  Third-party UI applications should start their own worker in order to comunicate with
  the server.
  """

  # __________API__________#

  @doc """
  Starts the server process.
  """
  def start_link() do
    with :ok <- verify_start() do
      GenServer.start_link(__MODULE__, nil, name: :dykm_client)
    else
      {:err, reason} ->
        raise "Couldn't start client: #{reason}"
    end
  end

  @doc """
  Registers the client by creating new user. Registration is a one-time event. It's
  possible to register for the second time only if the client has been unregistered
  beforehand.
  The username and password should be non-empty strings.
  Possbile responses are:
    {:err, :already_bound} - if the client is already associated with a user
    {:err, :invalid_format} - the username or password is not in the correct format
    {:err, server_error} - for more info on possible errors refer to the server module
    :ok - client was successfully bound to the newly-created user
  """
  @spec register(String.t(), String.t()) :: {:err, atom()} | :ok
  def register(name, password) do
    Logger.info("Client for #{name} is registering")
    GenServer.call(:dykm_client, {:register, name, password})
  end

  @doc """
  Associates the client with an already existing user by providing valid username and
  password. They should be non-empty strings.
  Possible responses are:
    {:err, :already_bound} - if the client is already associated with a user
    {:err, :invalid_format} - the username or password is not in the correct format
    {:err, server_error} - for more info on possible errors refer to the server module
    :ok - client was successfully bound to the specified user
  """
  @spec login(String.t(), String.t()) :: {:err, atom()} | :ok
  def login(name, password) do
    Logger.info("Client is logging in")
    GenServer.call(:dykm_client, {:login, name, password})
  end

  @doc """
  Unregisters the user that has been associated with the client. Unregistering is the
  process of deleting the user and all of their data from the database. This also
  dissociates the client from the user as the user doesn't exist anymore.
  Possible responses are:
    {:err, :not_bound} - if there's no user associated with the client
    {:err, server_error} - for more info on possible errors refer to the server module
    :ok - user was successfully unregistered
  """
  @spec unregister(String.t()) :: {:err, atom()} | :ok
  def unregister(password) do
    Logger.info("Client is unregistering")
    GenServer.call(:dykm_client, {:unregister, password})
  end

  @doc """
  Lists all invitations that the user has recieved.
  Possible responses are:
    {:err, :not_bound} - if there's no user associated with the client
    {:ok, [user_names]} - user was successfully unregistered
  """
  @spec get_invitations() :: {:err, atom()} | {:ok, [String.t()]}
  def get_invitations() do
    Logger.info("Client is listing invitations")

    GenServer.call(:dykm_client, :get_invitations)
  end

  @doc """
  Obtains one's username.
  """
  @spec username() :: nil | String.t()
  def username() do
    Logger.info("Client is fetching their username")

    GenServer.call(:dykm_client, :username)
  end

  @doc """
  Obtains a question to be guessed by the user.
  Possible responses are:
    {:err, :not_bound} - if there's no user associated with the client
    {:err, :no_such_question} - if there's no question from the specified user
    {:err, :invalid_format} - the question received from the server is not in the
  expected format {question_number, question_answer}
    {:err, server_error} - for more info on possible errors refer to the server module
    {:ok, {question, question_answer}} - question was obtained
  """
  @spec get_to_guess(String.t()) :: {:err, atom()} | {:ok, {question, String.t()}}
  def get_to_guess(other) do
    Logger.info("Client is fetching a question to guess from #{inspect(other)}")

    GenServer.call(:dykm_client, {:get_to_guess, other})
  end

  @doc """
  Obtains a question to be answered by the user.
  Possible responses are:
    {:err, :not_bound} - if there's no user associated with the client
    {:err, :no_such_question} - if there's no question from the specified user
    {:err, :invalid_format} - the question received from the server is not in the
  expected format
    {:err, server_error} - for more info on possible errors refer to the server module
    {:ok, question} - question was obtained
  """
  @spec get_to_answer(String.t()) :: {:err, atom()} | {:ok, question}
  def get_to_answer(other) do
    GenServer.call(:dykm_client, {:get_to_answer, other})
  end

  @doc """
  Obtains a guessed question to be reviewed by the user.
  Possible responses are:
    {:err, :not_bound} - if there's no user associated with the client
    {:err, :no_such_question} - if there's no question from the specified user
    {:err, :invalid_format} - the question received from the server is not in the
  expected format {question_num, answer, guess}
    {:err, server_error} - for more info on possible errors refer to the server module
    {:ok, {question, ans, guess}} - question was obtained
  """
  @spec get_to_see(String.t()) :: {:err, atom()} | {:ok, {question, String.t(), String.t()}}
  def get_to_see(other) do
    GenServer.call(:dykm_client, {:get_to_see, other})
  end

  @doc """
  Sends an invitation to the specified user.
  Possible responses are:
    {:err, :not_bound} - if there's no user associated with the client
    {:err, server_error} - for more info on possible errors refer to the server module
    :ok - invitation was send
  """
  @spec invite(String.t()) :: {:err, atom()} | :ok
  def invite(user) do
    Logger.info("Client is inviting #{user}")
    GenServer.call(:dykm_client, {:invite, user})
  end

  @doc """
  Declines an invitation from another user.
  Possible responses are:
    {:err, :not_bound} - if there's no user associated with the client
    {:err, :no_such_user} - if the specified user doesn't exist
    {:err, server_error} - for more info on possible errors refer to the server module
    :ok - the invitation was declined
  """
  @spec decline(String.t()) :: {:err, atom()} | :ok
  def decline(from) do
    Logger.info("Client is declining #{from}'s invitation")
    GenServer.call(:dykm_client, {:decline, from})
  end

  @doc """
  Accepts an invitation from another user.
  Possible responses are:
    {:err, :not_bound} - if there's no user associated with the client
    {:err, :no_such_user} - if the specified user doesn't exist
    {:err, server_error} - for more info on possible errors refer to the server module
    :ok - the invitation was accepted
  """
  @spec accept(String.t()) :: {:err, atom()} | :ok
  def accept(from) do
    Logger.info("Client is accepting #{from}'s invitation")
    GenServer.call(:dykm_client, {:accept, from})
  end

  @doc """
  Obtains scores with the specified user. A score is a float number representing
  a percentage of successfully guessed questions on each side.
  Possible responses are:
    {:err, :not_bound} - if there's no user associated with the client
    {:err, server_error} - for more info on possible errors refer to the server module
    {:ok, score1, score2} - score was obtained
  """
  @spec get_score(String.t()) :: {:err, atom()} | {:ok, float(), float()}
  def get_score(with_user) do
    Logger.info("Client is fetching scores with #{with_user}")
    GenServer.call(:dykm_client, {:get_score, with_user})
  end

  @doc """
  Lists all registered users, ignoring the associated user.
  Possible responses are:
    {:err, :not_bound} - if there's no user associated with the client
    {:err, server_error} - for more info on possible errors refer to the server module
    {:ok, user_list} - list was obtained
  """
  @spec list_registered :: {:err, atom()} | {:ok, [String.t()]}
  def list_registered() do
    Logger.info("Client is listing all registered clients")
    self_name = username()

    with {:ok, list} <- GenServer.call(:dykm_client, :list_registered) do
      {:ok, Enum.filter(list, fn user -> user != self_name end)}
    else
      error -> error
    end
  end

  @doc """
  Lists all users for which there is a game with the associated user.
  Possible responses are:
    {:err, :not_bound} - if there's no user associated with the client
    {:err, server_error} - for more info on possible errors refer to the server module
    {:ok, user_list} - list was obtained
  """
  @spec list_related :: {:err, atom()} | {:ok, [String.t()]}
  def list_related() do
    Logger.info("Client is listing all clients they're playing with")
    GenServer.call(:dykm_client, :list_related)
  end

  @doc """
  Gives answer to question sent from the speicified user.
  Answer must be "a", "b" or "c".
  Possible responses are:
    {:err, :not_bound} - if there's no user associated with the client
    {:err, :no_such_question} - if there's no question from the specified user
    {:err, :invalid_format} - if the answer is not in the correct format
    {:err, server_error} - for more info on possible errors refer to the server module
    :ok - question was answered successfully
  """
  @spec give_answer(String.t(), String.t()) :: {:err, atom()} | :ok
  def give_answer(other, answer) do
    Logger.info("Client's answer for #{other}'s question is #{answer}")
    GenServer.call(:dykm_client, {:answer, other, answer})
  end

  @doc """
  Gives guess to question answered by the speicified user.
  Guess must be "a", "b" or "c".
  Possible responses are:
    {:err, :not_bound} - if there's no user associated with the client
    {:err, :no_such_question} - if there's no question from the specified user
    {:err, :invalid_format} - if the guess is not in the correct format
    {:err, server_error} - for more info on possible errors refer to the server module
    :ok - question was guessed successfully
  """
  @spec give_guess(String.t(), String.t()) :: {:err, atom()} | {:ok, boolean()}
  def give_guess(other, guess) do
    Logger.info("Client's guess for #{other}'s question is #{guess}")
    GenServer.call(:dykm_client, {:guess, other, guess})
  end

  @doc """
  Used by the server. Not to be used by 3rd parties.
  """
  @impl Client.Behaviour
  def cast_invitation(client, from) do
    GenServer.cast({:dykm_client, client}, {:add_invitation, from})
  end

  @doc """
  Used by the server. Not to be used by 3rd parties.
  """
  @impl Client.Behaviour
  def cast_to_answer(client, from, q_num) do
    GenServer.cast({:dykm_client, client}, {:add_question, q_num, from})
  end

  @doc """
  Used by the server. Not to be used by 3rd parties.
  """
  @impl Client.Behaviour
  def cast_to_guess(client, from, q_num, answer) do
    GenServer.cast({:dykm_client, client}, {:add_guess, from, q_num, answer})
  end

  @doc """
  Used by the server. Not to be used by 3rd parties.
  """
  @impl Client.Behaviour
  def cast_to_see(client, from, q_num, answer, guess) do
    GenServer.cast({:dykm_client, client}, {:add_result, from, q_num, answer, guess})
  end

  # __________Callbacks__________#

  @doc """
  Initializes the server.
  """
  @impl true
  def init(_) do
    {:ok, State.new()}
  end

  @impl true
  def handle_call({:register, _, _}, _, state = %State{username: name}) when not is_nil(name) do
    {:reply, {:err, :already_bound}, state}
  end

  def handle_call({:register, username, pass}, _from, state) do
    if valid_password?(pass) and valid_username?(username) do
      with :ok <- server_module().register(username, pass) do
        {:reply, :ok, State.set_username(state, username)}
      else
        reason -> {:reply, {:err, reason}, state}
      end
    else
      {:reply, {:err, :invalid_format}, state}
    end
  end

  def handle_call({:login, _, _}, _, state = %State{username: name}) when not is_nil(name) do
    {:reply, {:err, :already_bound}, state}
  end

  def handle_call({:login, username, pass}, _from, state) do
    if valid_password?(pass) and valid_username?(username) do
      with :ok <- server_module().login(username, pass) do
        {:reply, :ok, State.set_username(state, username)}
      else
        reason -> {:reply, {:err, reason}, state}
      end
    else
      {:reply, {:err, :invalid_format}, state}
    end
  end

  def handle_call({:unregister, _pass}, _, state = %State{username: nil}) do
    {:reply, {:err, :not_bound}, state}
  end

  def handle_call({:unregister, pass}, _from, state) do
    with :ok <- server_module().unregister(pass) do
      {:reply, :ok, State.new()}
    else
      reason ->
        {:reply, {:err, reason}, state}
    end
  end

  def handle_call(:get_invitations, _, state) do
    if State.get_username(state) == nil do
      {:reply, {:err, :not_bound}, state}
    else
      {:reply, {:ok, State.get_invitations(state)}, state}
    end
  end

  def handle_call(:username, _from, state) do
    {:reply, State.get_username(state), state}
  end

  def handle_call({:get_to_guess, other_user}, _, %State{username: name} = state)
      when not is_nil(name) do
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

  def handle_call({:get_to_guess, _other_user}, _, state) do
    {:reply, {:err, :not_bound}, state}
  end

  def handle_call({:get_to_answer, other_user}, _, %State{username: name} = state)
      when not is_nil(name) do
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

  def handle_call({:get_to_answer, _other_user}, _, state) do
    {:reply, {:err, :not_bound}, state}
  end

  def handle_call({:get_to_see, other_user}, _, %State{username: name} = state)
      when not is_nil(name) do
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

  def handle_call({:get_to_see, _other_user}, _, state) do
    {:reply, {:err, :not_bound}, state}
  end

  def handle_call({:get_score, with_other}, _, %State{username: name} = state)
      when not is_nil(name) do
    with {:ok, _, _} = res <- server_module().get_score(with_other) do
      {:reply, res, state}
    else
      reason -> {:reply, {:err, reason}, state}
    end
  end

  def handle_call({:get_score, _}, _, state) do
    {:reply, {:err, :not_bound}, state}
  end

  def handle_call(:list_registered, _, %State{username: name} = state) when not is_nil(name) do
    with {:ok, list} <- server_module().list_users() do
      {:reply, {:ok, list}, state}
    else
      reason ->
        {:reply, {:err, reason}, state}
    end
  end

  def handle_call(:list_registered, _, state) do
    {:reply, {:err, :not_bound}, state}
  end

  def handle_call(:list_related, _, %State{username: name} = state) when not is_nil(name) do
    with {:ok, list} <- server_module().list_related() do
      {:reply, {:ok, list}, state}
    else
      reason ->
        {:reply, {:err, reason}, state}
    end
  end

  def handle_call(:list_related, _, state) do
    {:reply, {:err, :not_bound}, state}
  end

  def handle_call({:guess, _, _}, _, %State{username: nil} = state) do
    {:reply, {:err, :not_bound}, state}
  end

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

  def handle_call({:answer, _, _}, _, %State{username: nil} = state) do
    {:reply, {:err, :not_bound}, state}
  end

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

  def handle_call({:invite, to}, _, %State{username: name} = state) when not is_nil(name) do
    with :ok <- server_module().invite(to) do
      {:reply, :ok, state}
    else
      reason -> {:reply, {:err, reason}, state}
    end
  end

  def handle_call({:invite, _}, _, state) do
    {:reply, {:err, :not_bound}, state}
  end

  def handle_call({:accept, from}, _, %State{username: name} = state) when not is_nil(name) do
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

  def handle_call({:accept, _}, _, state) do
    {:reply, {:err, :not_bound}, state}
  end

  def handle_call({:decline, from}, _, %State{username: name} = state) when not is_nil(name) do
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

  def handle_call({:decline, _}, _, state) do
    {:reply, {:err, :not_bound}, state}
  end

  @impl true
  def handle_cast({:add_question, q, from}, state) do
    {:noreply, State.put_to_answer(state, from, q)}
  end

  def handle_cast({:add_guess, from, question, ans}, state) do
    {:noreply, State.put_to_guess(state, from, {question, ans})}
  end

  def handle_cast({:add_result, from, question, ans, guess}, state) do
    {:noreply, State.put_to_see(state, from, {question, ans, guess})}
  end

  def handle_cast({:add_invitation, from}, state) do
    {:noreply, State.add_invitation(state, from)}
  end

  # PRIVATE#


  defp verify_start do
    with {:ok, _} <- start_node(),
         true <- Node.connect(:"server@127.0.0.1") do
      :ok
    else
      {:err, _} -> {:err, :failed_to_start_node}
      false -> {:err, :failed_to_connect_to_server_node}
      :ignored -> {:err, :failed_to_start_node}
      _ -> {:err, :unexpected}
    end
  end

  defp start_node do
    if node() == :nonode@nohost do
      Node.start(:"#{:rand.uniform(999_999_999_999)}@127.0.0.1")
    else
      {:ok, :already_started}
    end
  end

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
