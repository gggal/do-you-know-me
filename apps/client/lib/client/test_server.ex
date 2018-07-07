defmodule TestServer do
  use GenServer

  require Logger

  def start_link() do
    GenServer.start_link(__MODULE__, nil, name: {:global, :quiz_server})
  end

  def init(_) do
    {:ok, {%{"username1" => %{node: :node1}}, %{node1: {"username1", true}}}}
  end

  def handle_info({:DOWN, _ref, :process, {_, node}, _reason}, {relations, clients}) do
    {name, _} = Map.get(clients, node)
    {:noreply, {relations, Map.put(clients, node, {name, false})}}
  end

  def handle_call(:reconnect, {from, _}, {relations, clients} = state) do
    case get_username(from, state) do
      nil ->
        {:reply, :not_registered, state}

      name ->
        send_after_reconnect(name, state)
        {:reply, :ok, {relations, Map.put(clients, node(from), {name, true})}}
    end
  end

  def handle_call({:register, user}, {from, _}, {relations, clients} = state) do
    case get_username(from, state) do
      nil ->
        case Map.has_key?(relations, user) do
          true ->
            {:reply, :taken, {relations, clients}}

          false ->
            updated_relations = Map.put(relations, user, %{node: node(from)})
            updated_clients = Map.put(clients, node(from), {user, true})
            Process.monitor({:quiz_client, node(from)})
            {:reply, :registered, {updated_relations, updated_clients}}
        end

      _ ->
        {:reply, :already_registered, state}
    end
  end

  def handle_call(:unregister, {from, _}, {relations, clients} = state) do
    # Logger.info("Client #{from} with name #{user} is trying to unregister.")
    case get_username(from, state) do
      nil ->
        {:reply, :not_registered, state}

      user ->
        new_relations =
          remove_user(
            Map.delete(relations, user),
            user,
            Map.get(relations, user) |> Enum.map(fn {o, _} -> o end)
          )

        {:reply, :unregistered, {new_relations, Map.delete(clients, node(from))}}
    end
  end

  def handle_call(:get_rating, {from, _}, {relations, _} = state) do
    # Logger.info("Client #{of} is getting rate with everyone.")

    case get_username(from, state) do
      nil ->
        {:reply, :not_registered, state}

      of ->
        {:reply,
         relations
         |> Map.get(of, %{})
         |> Map.delete(:node)
         |> Enum.map(fn {other, _} -> get_rating(of, other, relations) end)
         |> Enum.filter(fn {_, a, b} -> a + b > 0 end), state}
    end
  end

  def handle_call({:get_rating, user2}, {from, _}, {relations, _} = state) do
    # Logger.info("Client #{user1} is getting rate with #{user2}.")
    case get_username(from, state) do
      nil ->
        {:reply, :not_registered, state}

      user1 ->
        case Map.get(relations, user1) |> Map.get(user2) do
          nil -> {:reply, :not_playing, state}
          {_, _} -> {:reply, get_rating(user1, user2, relations), state}
        end
    end
  end

  def handle_call(:list_registered, _, {relations, clients}) do
    {:reply,
     relations
     |> Enum.map(fn {name, _} -> name end), {relations, clients}}
  end

  def handle_cast({:invitation, from, to}, {relations, clients} = state) do
    case(Map.get(relations, from) == nil || Map.get(relations, to) == nil) do
      true ->
        {:noreply, state}

      false ->
        case Map.get(relations, from) |> Map.get(to) do
          nil ->
            case Map.get(relations, to) |> Map.get(from) do
              nil ->
                %{node: to_node} = Map.get(relations, to)
                GenServer.cast({:quiz_client, to_node}, {:add_invitation, from})

                {:noreply,
                 {%{relations | from => Map.put(Map.get(relations, from), to, {0, 0})}, clients}}

              _game_state ->
                new_from_map = Map.put(Map.get(relations, from), to, {0, 0})
                %{node: from_node} = Map.get(relations, from)
                GenServer.cast({:quiz_client, from_node}, {:add_question, to, 0})
                {:noreply, {Map.put(relations, from, new_from_map), clients}}
            end

          _game_state ->
            {:noreply, {relations, clients}}
        end
    end
  end

  def handle_cast({:accept, from, to}, {relations, clients} = state) do
    case(Map.get(relations, from) == nil || Map.get(relations, to) == nil) do
      true ->
        {:noreply, state}

      false ->
        case Map.get(relations, from) |> Map.get(to) do
          nil ->
            case Map.get(relations, to) |> Map.get(from) do
              nil ->
                {:noreply, state}

              _game_state ->
                new_from_map = Map.put(Map.get(relations, from), to, {0, 0})
                %{node: from_node} = Map.get(relations, from)
                GenServer.cast({:quiz_client, from_node}, {:add_question, to, 0})
                {:noreply, {Map.put(relations, from, new_from_map), clients}}
            end

          _game_state ->
            {:noreply, {relations, clients}}
        end
    end
  end

  def handle_cast({:decline, from, to}, {relations, clients} = state) do
    case(Map.get(relations, from) == nil || Map.get(relations, to) == nil) do
      true ->
        {:noreply, state}

      false ->
        case Map.get(relations, from) |> Map.get(to) do
          nil ->
            case Map.get(relations, to) |> Map.get(from) do
              nil ->
                {:noreply, state}

              _game_state ->
                {:noreply,
                 {%{relations | to => Map.delete(Map.get(relations, to), from)}, clients}}
            end

          _game_state ->
            {:noreply, {relations, clients}}
        end
    end
  end

  def handle_cast({:guess, from, to, q, answer, guess}, {relations, clients} = state)
      when answer == guess do
    case valid_username?(from, state) && valid_username?(to, state) do
      false ->
        {:noreply, state}

      true ->
        %{node: from_node} = Map.get(relations, from)
        %{node: to_node} = Map.get(relations, to)
        GenServer.cast({:quiz_client, to_node}, {:add_result, from, q, answer, guess})
        GenServer.cast({:quiz_client, from_node}, {:add_question, 0, to})
        {guessed, missed} = Map.get(relations, from, %{}) |> Map.get(to)
        map1 = Map.get(relations, from)
        map2 = Map.put(map1, to, {guessed + 1, missed})
        {:noreply, {%{relations | from => map2}, clients}}
    end
  end

  def handle_cast({:guess, from, to, q, answer, _answer}, {relations, clients} = state) do
    case valid_username?(from, state) && valid_username?(to, state) do
      false ->
        {:noreply, state}

      true ->
        %{node: from_node} = Map.get(relations, from)
        %{node: to_node} = Map.get(relations, to)
        GenServer.cast({:quiz_client, to_node}, {:add_result, from, q, answer, answer})
        GenServer.cast({:quiz_client, from_node}, {:add_question, 0, to})
        {guessed, missed} = Map.get(relations, from) |> Map.get(to)
        map1 = Map.get(relations, from)
        map2 = Map.put(map1, to, {guessed, missed + 1})
        {:noreply, {%{relations | from => map2}, clients}}
    end
  end

  def handle_cast({:answer, from, to, q, answer}, {relations, _} = state) do
    case valid_username?(from, state) && valid_username?(to, state) do
      false ->
        {:noreply, state}

      true ->
        %{node: to_node} = Map.get(relations, to)
        GenServer.cast({:quiz_client, to_node}, {:add_guess, from, q, answer})
        {:noreply, state}
    end
  end

  def handle_cast({:client_send_to_see, from, to, ans, guess}, {relations, _} = state) do
    %{node: to_node} = Map.get(relations, to)
    GenServer.cast({:quiz_client, to_node}, {:add_result, from, 0, ans, guess})
    {:noreply, state}
  end

  def handle_cast({:client_send_to_answer, from, to}, {relations, _} = state) do
    %{node: to_node} = Map.get(relations, to)
    GenServer.cast({:quiz_client, to_node}, {:add_question, 0, from})
    {:noreply, state}
  end

  def handle_cast({:client_send_to_guess, from, to, guess}, {relations, _} = state) do
    %{node: to_node} = Map.get(relations, to)
    GenServer.cast({:quiz_client, to_node}, {:add_guess, from, 0, guess})
    {:noreply, state}
  end

  def handle_cast({:client_send_invitation, from, to}, {relations, clients}) do
    %{node: to_node} = Map.get(relations, to)
    GenServer.cast({:quiz_client, to_node}, {:add_invitation, from})
    {:noreply, {Map.put(relations, from, Map.put(Map.get(relations, from), to, {0, 0})), clients}}
  end

  # PRIVATE#

  defp sum_rating({0, 0}), do: 100.0
  defp sum_rating({per1, per2}), do: 100 * per1 / (per1 + per2)

  defp get_rating(from, to, all) do
    case Map.get(all, from, %{}) |> Map.get(to) do
      nil ->
        {to, -1, -1}

      {_, _} = guesses ->
        case Map.get(all, to, %{}) |> Map.get(from) do
          nil -> {to, 1, -1}
          {_, _} = o_guesses -> {to, sum_rating(guesses), sum_rating(o_guesses)}
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
            GenServer.cast({:quiz_client, other_node}, {:add_question, user, 0})

          # it was dissconnected player's turn
          false ->
            %{node: user_node} = Map.get(relations, user)
            GenServer.cast({:quiz_client, user_node}, {:add_question, other, 0})
        end
    end
  end
end
