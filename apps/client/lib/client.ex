defmodule Client.Application do
  @moduledoc """
  Once registered, a client can send an invitation to every registered user. If the user accepts the
  invitation, they receive a question that they have to answer. After that the other user receives
  the same question and has to try to guess the first user's answer.
  """

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

      IO.puts("result")
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
    GenServer.call(:quiz_client, {:register, name})
  end

  @doc """
  Unregistering client. This is the only way client's data can be wiped out. After unregistering a client
  can register again under the same or different name. Returns :not_registered if client is not registered.
  Returns :unregister if the unregistering is successful.
  """
  def unregister() do
    GenServer.call(:quiz_client, :unregister)
  end

  @doc """
  Returns a map with all current invitations.
  """
  def get_invitations() do
    GenServer.call(:quiz_client, :see_invitations)
    |> Enum.map(fn {key, _val} -> key end)
  end

  def invite(user) do
    GenServer.cast(:quiz_client, {:invite, user})
  end

  @doc """
  Declines an invitation from `from` if it exists.
  """
  def decline(from) do
    GenServer.cast(:quiz_client, {:decline, from})
  end

  @doc """
  Accepts an invitation from `from` if it exists.
  """
  def accept(from) do
    GenServer.cast(:quiz_client, {:accept, from})
  end

  @doc """
  Gives answer to question sent from `other`. Answer should be :a, :b, :c.
  """
  def give_answer(other, answer) do
    GenServer.cast(:quiz_client, {:answer, other, answer})
  end

  def give_guess(other, guess) do
    GenServer.call(:quiz_client, {:guess, other, guess})
  end

  def username() do
    GenServer.call(:quiz_client, :username)
  end

  def get_to_guess() do
    GenServer.call(:quiz_client, :get_to_guess)
  end

  def get_to_answer() do
    GenServer.call(:quiz_client, :get_to_answer)
  end

  def get_to_see() do
    GenServer.call(:quiz_client, :get_to_see)
  end

  def get_rating() do
    GenServer.call(:quiz_client, :get_rating)
  end

  def get_rating(with) do
    GenServer.call(:quiz_client, {:get_rating, with})
  end

  def list_registered() do
    GenServer.call(:quiz_client, :list_registered)
  end

  @doc """
  Lists all users that are playing with the current user
  """
  def list_related() do
    GenServer.call(:quiz_client, :get_related)
  end
end
