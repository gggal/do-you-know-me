defmodule Server.State do
  alias __MODULE__

  @type t :: %State{}

  @enforce_keys [:users, :clients]
  defstruct [:users, :clients]

  @moduledoc """
  This module represents the DYKM server's internal state. It contains all the relevent
   information about online users - what is their username and their list of nodes
   from which they had logged in (clients). A user can have multiple clients but there's
   only one user per client.
  """

  @doc """
  Initiate the state.
  """
  def new() do
    %State{users: %{}, clients: %{}}
  end

  @doc """
  Adds a new user - client pair to the state.
  """
  @spec add(State.t(), String.t(), atom) :: State.t()
  def add(%State{users: users, clients: clients}, user, client) do
    curr_clients = Map.get(users, user, [])

    %State{
      users: Map.put(users, user, curr_clients ++ [client]),
      clients: Map.put(clients, client, user)
    }
  end

  @doc """
  Deletes a user and every node that is associated with it.
  """
  @spec delete(State.t(), String.t()) :: State.t()
  def delete(%State{users: users, clients: clients}, user) do
    curr_clients = Map.get(users, user, [])

    %State{
      users: Map.delete(users, user),
      clients: Map.drop(clients, curr_clients)
    }
  end

  @doc """
  Deletes a client. If it's the last client for the user, the user gets deleted as well.
  """
  @spec delete_client(State.t(), atom) :: State.t()
  def delete_client(state = %State{users: users, clients: clients}, client) do
    with user when not is_nil(user) <- get_user(state, client),
         curr_clients <- get_clients(state, user) do
      if [client] == curr_clients do
        delete(state, user)
      else
        %State{
          users: Map.put(users, user, curr_clients -- [client]),
          clients: Map.delete(clients, client)
        }
      end
    else
      _ -> state
    end
  end

  @doc """
  Returns true if the user is already added, false otherwise.
  """
  @spec contains_user?(State.t(), String.t()) :: boolean
  def contains_user?(%State{users: users}, user), do: Map.has_key?(users, user)

  @doc """
  Returns true if the client is already added, false otherwise.
  """
  @spec contains_client?(State.t(), atom) :: boolean
  def contains_client?(%State{clients: clients}, client) do
    Map.has_key?(clients, client)
  end

  @doc """
  Returns the list of clients for the specified user.
  """
  @spec get_clients(State.t(), String.t()) :: [atom]
  def get_clients(%State{users: users}, user), do: Map.get(users, user, [])

  @doc """
  Returns the use for the specified client.
  """
  @spec get_user(State.t(), atom) :: String.t()
  def get_user(%State{clients: clients}, client), do: Map.get(clients, client)
end
