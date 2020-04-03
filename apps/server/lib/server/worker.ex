defmodule Server.Worker do
  use GenServer

  require Logger

  alias Server.User
  alias Server.Invitation

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
    GenServer.start_link(__MODULE__, {%{}, %{}}, name: {:global, :quiz_server})
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
  def handle_info({:DOWN, _ref, :process, {_, node}, reason}, {relations, clients}) do
    {name, _} = Map.get(clients, node)
    Logger.info("Client #{name} has disconnected: #{reason}")
    {:noreply, {relations, Map.put(clients, node, {name, false})}}
  end

  @doc """
  Called in case a registered client is connected again.
  """
  def handle_call(:reconnect, {from, _}, {relations, clients} = state) do
    case get_username(from, state) do
      nil ->
        # client tries to reconnect without ever being connected
        {:reply, :not_registered, state}

      name ->
        # check if the given password is correct - if is, send everything to the user
        send_after_reconnect(name, state)
        {:reply, :ok, {relations, Map.put(clients, node(from), {name, true})}}
    end
  end

  @doc """
  Registers new user.
  Returns :taken if the name the user picked is already taken. Returns :already_registered if this
  client is already registered with different name. Returns :ok otherwise.
  """
  def handle_call({:register, user}, {from, _}, {relations, clients} = state) do
    case get_username(from, state) do
      nil ->
        case User.exists?(user) do
          true ->
            {:reply, :taken, {relations, clients}}

          false ->
            Logger.info("New client registered under the username #{user}")
            User.insert(user)

            # %User{username: user, password: "default_password"} |> DB.Repo.insert()

            updated_relations = Map.put(relations, user, %{node: node(from)})
            updated_clients = Map.put(clients, node(from), {user, true})
            Process.monitor({:quiz_client, node(from)})
            {:reply, :registered, {updated_relations, updated_clients}}
        end

      old_username ->
        Logger.error(
          "Client registered once as #{old_username} is trying to register again as username #{
            user
          }"
        )

        {:reply, :already_registered, state}
    end
  end

  def handle_call({:login, user}, {from, _}, {relations, clients} = state) do
    case get_username(from, state) do
      nil ->
        case User.exists?(user) do
          true ->
            updated_relations = Map.put(relations, user, %{node: node(from)})
            updated_clients = Map.put(clients, node(from), {user, true})
            Process.monitor({:quiz_client, node(from)})
            {:reply, :registered, {updated_relations, updated_clients}}

          false ->
            Logger.error(
              "Client is trying to login in with user #{user} but no such user exists."
            )

            {:reply, :no_such_user, state}
        end

      _ ->
        Logger.error("Client is trying to login in with user #{user} but is already loged in.")
        {:reply, :already_logged_in, state}
    end
  end

  @doc """
  Unregisters registered client. Returns :not_registered if the client hadn't been registered.
  Returns :unregistered otherwise.
  """
  def handle_call(:unregister, {from, _}, {relations, clients} = state) do
    case get_username(from, state) do
      nil ->
        # client tries to unregister but hasn't been registered
        {:reply, :not_registered, state}

      user ->
        # maybe delete everything about this user - or better, map the user as inactive!
        new_relations =
          remove_user(
            Map.delete(relations, user),
            user,
            Map.get(relations, user) |> Enum.map(fn {o, _} -> o end)
          )

        {:reply, :unregistered, {new_relations, Map.delete(clients, node(from))}}
    end
  end

  @doc """
  Returns list of tuples {other, per1, per2} - current game states between /user1 and everyone that
  he/she is playing with. `other` is the username of the other user, `per1` and `per2` are the
  percentages of right guessed questions for every user.
  """
  def handle_call(:get_rating, {from, _}, {relations, _} = state) do
    case get_username(from, state) do
      nil ->
        # client is not registered
        {:reply, :not_registered, state}

      of ->
        # get all states/signle game state and format the scores
        {:reply,
         relations
         |> Map.get(of, %{})
         |> Map.delete(:node)
         |> Enum.map(fn {other, _} -> get_rating(of, other, relations) end)
         |> Enum.filter(fn {_, a, b} -> a + b > 0 end), state}
    end
  end

  @doc """
  Returns {per1, per2} - current game state between `user1` and `user2` where per1 and per2 are the
  according percentages of right guessed questions for every user.
  """
  def handle_call({:get_rating, user2}, {from, _}, {relations, _} = state) do
    case get_username(from, state) do
      nil ->
        {:reply, :not_registered, state}

      user1 ->
        case Map.get(relations, user1) |> Map.get(user2) do
          nil ->
            {:reply, :not_playing, state}

          {_, _} ->
            {:reply, get_rating(user1, user2, relations), state}
        end
    end
  end

  @doc """
   Returns list of all registered clients (connected or dissconnected).
  """
  def handle_call(:list_registered, _, {relations, clients}) do
    # get all users from users table
    {:reply,
     relations
     |> Enum.map(fn {name, _} -> name end), {relations, clients}}
  end

  @doc """
  Returns a list of all players the client is currently playing with.
  """
  def handle_call(:list_related, {from, _}, {relations, clients} = state) do
    username = get_username(from, state)

    {:reply, Map.get(relations, username, %{}) |> Map.delete(:node) |> Map.keys(),
     {relations, clients}}
  end

  def handle_call(:dump, {_from, _}, {relations, clients} = state) do
    IO.inspect(state)

    {:reply, "", {relations, clients}}
  end

  @doc """
  A client `from` is sending an invitation to `to`. If `to` had sent an invitation to `from`, the game
  is assuming that `to` wants to play and an invitation wont be send, instead they will start playing.
  In case `from` or `to` isn't registered or they're already playing nothing is done.
  """
  def handle_cast({:invitation, from, to}, {relations, clients} = state) do
    case not User.exists?(from) or not User.exists?(to) do
      true ->
        {:noreply, state}

      false ->
        case Invitation.exists?(from, to) or playing?(from, to) do
          false ->
            case Invitation.exists?(to, from) do
              false ->
                %{node: to_node} = Map.get(relations, to)
                GenServer.cast({:quiz_client, to_node}, {:add_invitation, from})
                Logger.info("Client #{from} invited client #{to}")

                Invitation.insert(from, to)

                {:noreply,
                 {%{relations | from => Map.put(Map.get(relations, from), to, {{0, 0}, true})},
                  clients}}

              _game_state ->
                new_from_map = Map.put(Map.get(relations, from), to, {{0, 0}, true})
                %{node: from_node} = Map.get(relations, from)
                GenServer.cast({:quiz_client, from_node}, {:add_question, fetch_question(), to})
                Logger.info("Clients #{from} and #{to} invited each other")
                {:noreply, {Map.put(relations, from, new_from_map), clients}}
            end

          _game_state ->
            Logger.info(
              "Client #{from} tried to invite client #{to} but they are already playing"
            )

            {:noreply, {relations, clients}}
        end
    end
  end

  @doc """
  Client `from` is accepting `to` 's invitation.
  In case `from` or `to` isn't registered or they're already playing nothing is done.
  """
  def handle_cast({:accept, from, to}, {relations, clients} = state) do
    case not User.exists?(from) and not User.exists?(to) do
      true ->
        Logger.info(
          "Client #{from} failed to accept client #{to}'s invitation: someone of them is not registered"
        )

        {:noreply, state}

      false ->
        case Map.get(relations, from) |> Map.get(to) do
          nil ->
            case Map.get(relations, to) |> Map.get(from) do
              nil ->
                Logger.info(
                  "Client #{from} failed to accept client #{to}'s invitation: no invitation"
                )

                {:noreply, state}

              _game_state ->
                # remove the from->to pair from invitations
                # put a new pair in games and game_state
                new_from_map = Map.put(Map.get(relations, from), to, {{0, 0}, true})
                %{node: from_node} = Map.get(relations, from)
                GenServer.cast({:quiz_client, from_node}, {:add_question, fetch_question(), to})

                Invitation.delete(to, from)
                Logger.info("Client #{from} accepted client #{to}'s invitation")
                {:noreply, {Map.put(relations, from, new_from_map), clients}}
            end

          _game_state ->
            Logger.warn(
              "Inconsistant state: client #{from} is trying to accept #{to}'s invitation but
            #{from} had already invited #{to}"
            )

            {:noreply, {relations, clients}}
        end
    end
  end

  @doc """
  Client `from` is declining `to`'s invitation.
  In case `from` or `to` isn't registered or they're already playing nothing is done.
  """
  def handle_cast({:decline, from, to}, {relations, clients} = state) do
    case not User.exists?(from) and not User.exists?(to) do
      true ->
        Logger.info(
          "Client #{from} failed to decline client #{to}'s invitation: someone of them is not registered"
        )

        {:noreply, state}

      false ->
        case Map.get(relations, from) |> Map.get(to) do
          nil ->
            case Map.get(relations, to) |> Map.get(from) do
              nil ->
                Logger.info(
                  "Client #{from} failed to decline client #{to}'s invitation: no invitation"
                )

                {:noreply, state}

              _game_state ->
                Invitation.delete(to, from)
                # remove the from->to pair from invitations
                Logger.info("Client #{from} declined client #{to}'s invitation")

                {:noreply,
                 {%{relations | to => Map.delete(Map.get(relations, to), from)}, clients}}
            end

          _game_state ->
            Logger.warn(
              "Inconsistant state: client #{from} is trying to decline #{to}'s invitation but
            #{from} had already invited #{to}"
            )

            {:noreply, {relations, clients}}
        end
    end
  end

  @doc """
  User `from` has guessed `to`'s answer correctly. The server sends the same question and `from`'s
   answer to `to` so he/she can see if `from` had guessed and adds the guess to their game state.
  """
  def handle_cast({:guess, from, to, q, answer, guess}, {relations, clients} = state)
      when answer == guess do
    case valid_username?(from, state) && valid_username?(to, state) do
      false ->
        Logger.info("Client #{from} failed to guess #{to}'s answer: invalid username")
        {:noreply, state}

      true ->
        # add question entry
        # change the game_state entry - add the q
        %{node: from_node} = Map.get(relations, from)
        %{node: to_node} = Map.get(relations, to)
        GenServer.cast({:quiz_client, to_node}, {:add_result, from, q, answer, guess})
        GenServer.cast({:quiz_client, to_node}, {:add_question, fetch_question(), from})
        {{guessed, missed}, is_first} = Map.get(relations, from, %{}) |> Map.get(to)
        map1 = Map.get(relations, from)
        map2 = Map.put(map1, to, {{guessed + 1, missed}, is_first})
        Logger.info("Client #{from} guessed #{guess}'s answer correctly. Answer was #{answer}")
        {:noreply, {%{relations | from => map2}, clients}}
    end
  end

  @doc """
  User `from` has guessed `to`'s answer incorrectly. The server sends the same question and `from`'s
  answer to `to` so he/she can see if `from` had guessed and adds the guess to their game state.
  """
  def handle_cast({:guess, from, to, q, answer, guess}, {relations, clients} = state) do
    case valid_username?(from, state) && valid_username?(to, state) do
      false ->
        Logger.info("Client #{from} failed to guess #{to}'s answer: invalid username")
        {:noreply, state}

      true ->
        # add question entry
        # change the game_state entry - add the q

        # %{node: from_node} = Map.get(relations, from)
        %{node: to_node} = Map.get(relations, to)
        GenServer.cast({:quiz_client, to_node}, {:add_result, from, q, answer, guess})
        # GenServer.cast({:quiz_client, from_node}, {:add_question, fetch_question(), to})
        GenServer.cast({:quiz_client, to_node}, {:add_question, fetch_question(), from})
        {{guessed, missed}, is_first} = Map.get(relations, from) |> Map.get(to)
        map1 = Map.get(relations, from)
        map2 = Map.put(map1, to, {{guessed, missed + 1}, is_first})

        Logger.info(
          "Client #{from} guessed #{guess}'s answer incorrectly. Guess was #{guess}, answer was #{
            answer
          }"
        )

        {:noreply, {%{relations | from => map2}, clients}}
    end
  end

  @doc """
  User `from` has answered to a question in a game with `to`. The server sends the same question
  to `to` who has to guess `from`'s answer.
  """
  def handle_cast({:answer, from, to, q, answer}, {relations, clients} = state) do
    case valid_username?(from, state) && valid_username?(to, state) do
      false ->
        Logger.info(
          "Client #{from} failed to answer a question while playing with #{to}: invalid username"
        )

        {:noreply, state}

      true ->
        # add new question
        # change the game_state entry by adding an answer to the question and
        %{node: to_node} = Map.get(relations, to)
        GenServer.cast({:quiz_client, to_node}, {:add_guess, from, q, answer})

        # in case this it the first level ask a question to the other user
        Logger.info("About to add answer for user #{to} #{first_lvl?(from, to, relations)}")

        if first_lvl?(from, to, relations) do
          GenServer.cast({:quiz_client, to_node}, {:add_question, fetch_question(), from})
        end

        Logger.info("Client #{from} answered #{answer} while playing with #{to}")
        {:noreply, {update_related(relations, from, to), clients}}
    end
  end

  def questions_count(), do: @questions_count

  # PRIVATE#

  defp fetch_question() do
    :rand.uniform(@questions_count)
  end

  defp sum_rating({0, 0}), do: 100.0
  defp sum_rating({per1, per2}), do: 100 * per1 / (per1 + per2)

  defp first_lvl?(from, to, all) do
    Logger.info("#{inspect(all)}")

    case Map.get(all, from, %{}) |> Map.get(to) do
      {_, false} ->
        false

      {_, true} ->
        true
    end
  end

  defp update_related(related, from, to) do
    case Map.get(related, from, %{}) |> Map.get(to) do
      nil ->
        related

      {_, _} ->
        case Map.get(related, to, %{}) |> Map.get(from) do
          nil ->
            related

          {_, false} ->
            related

          {pair, true} ->
            %{
              %{related | from => %{Map.get(related, from) | to => {pair, false}}}
              | to => %{Map.get(related, to) | from => {pair, false}}
            }
        end
    end
  end

  defp get_rating(from, to, all) do
    case Map.get(all, from, %{}) |> Map.get(to) do
      nil ->
        {to, -1, -1}

      {{_, _} = guesses, _} ->
        case Map.get(all, to, %{}) |> Map.get(from) do
          nil -> {to, 1, -1}
          {{_, _} = o_guesses, _} -> {to, sum_rating(guesses), sum_rating(o_guesses)}
        end
    end
  end

  defp remove_user(state, _, []), do: state

  defp remove_user(state, user, [other | others]) do
    case Map.has_key?(state, other) do
      true ->
        %{remove_user(state, user, others) | other => Map.delete(Map.get(state, other), user)}

      false ->
        remove_user(state, user, others)
    end
  end

  defp valid_username?(name, {names, _}), do: Map.has_key?(names, name)

  defp get_username(pid, {_, nodes}), do: Map.get(nodes, node(pid), {nil, nil}) |> elem(0)

  defp send_after_reconnect(name, {relations, _}) do
    Map.get(relations, name)
    |> Map.delete(:node)
    |> Enum.map(fn {other, _} -> other end)
    |> Enum.map(fn other -> send_question(name, other, relations) end)
  end

  defp send_question(user, other, relations) do
    res1 = Map.get(relations, user) |> Map.get(other)
    res2 = Map.get(relations, other) |> Map.get(user)

    case res1 == nil || res2 == nil do
      true ->
        nil

      false ->
        {hits1, misses1} = res1
        {hits2, misses2} = res2

        case hits1 + misses1 > hits2 + misses2 do
          # it was other's turn
          true ->
            %{node: other_node} = Map.get(relations, other)
            GenServer.cast({:quiz_client, other_node}, {:add_question, fetch_question(), user})

          # it was dissconnected player's turn
          false ->
            %{node: user_node} = Map.get(relations, user)
            GenServer.cast({:quiz_client, user_node}, {:add_question, fetch_question(), other})
        end
    end
  end

  defp reorder(user1, user2) when user1 > user2, do: {user2, user1}
  defp reorder(user1, user2), do: {user1, user2}

  defp playing?(user1, user2) do
    false
  end
end
