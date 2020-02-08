defmodule Client.Application do
  @moduledoc """
  Single point of access between the user interfaces and the client.
  """

  require Logger

  use Application

  @doc """
  Starting the client application
  """
  def start(_, _) do
    import Supervisor.Spec, warn: false

    with nick when not is_nil(nick) <- Client.Connectivity.nick(),
         true <- Client.Connectivity.connect_to_server_node("127.0.0.1") do
      children = [
        # Starts a worker by calling: Client.Worker.start_link(arg)
        worker(Client.Worker, [])
      ]

      # IO.puts(:global.whereis_name(:quiz_server))

      opts = [strategy: :one_for_one, name: Client.Supervisor]
      Supervisor.start_link(children, opts)
    else
      _ -> {:error, "Can't connect to server or establish client."}
    end
  end

  @doc """
  Registering client. Once registered the client's data will be saved by the server even if the client is
  disconnected. This data is relations with the other players. If `name` id is is already taken by another
  user or this node is associated with another user, registration will fail and :taken will
  be returned. Returns :registered otherwise.
  """
  def register(name) do
    Logger.info("Client is registering")
    GenServer.call(:quiz_client, {:register, name})
  end

  @doc """
  Unregistering client. This is the only way client's data can be wiped out. After unregistering a client
  can register again under the same or different name. Returns :not_registered if client is not registered.
  Returns :unregister if the unregistering is successful.
  """
  def unregister() do
    Logger.info("Client is unregistering")
    GenServer.call(:quiz_client, :unregister)
  end

  @doc """
  Returns a map with all current invitations.
  """
  def get_invitations() do
    Logger.info("Client is listing invitations")
    GenServer.call(:quiz_client, :see_invitations)
    |> Enum.map(fn {key, _val} -> key end)
  end

  @doc """
  Sends invitation to `user`, doesn't wait for the response.
  """
  def invite(user) do
    Logger.info("Client is inviting #{user}")
    GenServer.cast(:quiz_client, {:invite, user})
  end

  @doc """
  Declines an invitation from `from` if it exists.
  """
  def decline(from) do
    Logger.info("Client is declining #{from}'s invitation")
    GenServer.cast(:quiz_client, {:decline, from})
  end

  @doc """
  Accepts an invitation from `from` if it exists.
  """
  def accept(from) do
    Logger.info("Client is accepting #{from}'s invitation")
    GenServer.cast(:quiz_client, {:accept, from})
  end

  @doc """
  Gives answer to question sent from `other`. Answer should be :a, :b, :c.
  """
  def give_answer(other, answer) do
    Logger.info("Client's answer for #{other}'s question is #{answer}")
    GenServer.cast(:quiz_client, {:answer, other, answer})
  end

  @doc """
  Gives guess to question answered from `other`. Answer should be :a, :b, :c.
  """
  def give_guess(other, guess) do
    Logger.info("Client's guess for #{other}'s question is #{guess}")
    GenServer.call(:quiz_client, {:guess, other, guess})
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
    Logger.info("Client is fetching a question to guess from #{other}")
    GenServer.call(:quiz_client, :get_to_guess) |> Map.get(other, nil)
  end

  @doc """
  Obtain a question to be answered by the user
  """
  def get_to_answer(other) do
    Logger.info("Client is fetching a question to answer from #{other}")
    GenServer.call(:quiz_client, :get_to_answer) |> Map.get(other, nil)
  end

  @doc """
  Obtain a question to be reviewed by the user
  """
  def get_to_see(other) do
    Logger.info("Client is fetching a question to review from #{other}")
    GenServer.call(:quiz_client, :get_to_see) |> Map.get(other, nil)
  end

  @doc """
  Obtain all scores
  """
  def get_rating() do
    Logger.info("Client is fetching all scores")
    GenServer.call(:quiz_client, :get_rating)
  end

  @doc """
  Obtain scores with user `with`
  """
  def get_rating(with) do
    Logger.info("Client is fetching scores with #{with}")
    GenServer.call(:quiz_client, {:get_rating, with})
  end

  @doc """
  List all registered users
  """
  def list_registered() do
    Logger.info("Client is listing all registered clients")
    GenServer.call(:quiz_client, :list_registered)
  end

  @doc """
  Lists all users that are playing with the current user
  """
  def list_related() do
    Logger.info("Client is listing all clients they're playing with")
    GenServer.call(:quiz_client, :get_related)
  end
end
