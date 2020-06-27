defmodule CLI do
  @moduledoc """
  This module represents the command line interface
  """

  use GenServer

  require Logger

  alias CLI.State

  @doc """
  Starts the command line interface
  """
  def main(_cmd_args) do
    CLI.start_game()
  end

  @doc """
  Starts the genserver
  """
  def start_link() do
    GenServer.start_link(__MODULE__, nil, name: :cli)
  end

  @doc """
  Adds an invitation to be should as a notification to the player.
  """
  def notify_invite(inviter) do
    GenServer.cast(:cli, {:notify_invite, inviter})
  end

  # __________Callbacks__________#

  @impl true
  def init(_) do
    {:ok, State.new()}
  end

  @impl true
  def handle_cast({:notify_invite, other_player}, state) do
    {:noreply, State.add_invite(state, other_player)}
  end

  @impl true
  def handle_call(:get_invites, _, state) do
    {:reply, State.get_invites(state), state}
  end

  def handle_call(:delete_invites, _, state) do
    {:reply, :ok, State.delete_invites(state)}
  end

  # __________Private__________#

  def start_game() do
    CLI.Util.print_separator()
    IO.puts("\t\tDO YOU KNOW ME\n")

    loop([])
  end

  defp loop(args) do
    CLI.Util.print_separator()

    curr_state = StateMachine.get_state()
    print_notifications(curr_state)
    update_notifications(curr_state)
    {move, new_args} = run_game_action(curr_state, args)

    case StateMachine.move(move) do
      :err ->
        Logger.error("Invalid game state: tried to move from #{curr_state} with #{move}.")
        IO.puts("Something went wrong.")

      {:ok, :exit} ->
        IO.puts("Exit game")

      {:ok, _next_state} ->
        loop(new_args)
    end
  end

  defp print_notifications(:main_menu) do
    invites = GenServer.call(:cli, :get_invites)

    if invites != [] do
      IO.puts("\n(** New invitation(s) from #{player_list_to_string(invites)} **)\n")
    end
  end

  defp print_notifications(_), do: :ok

  defp update_notifications(:invitation_menu) do
    GenServer.call(:cli, :delete_invites)
  end

  defp update_notifications(_), do: :ok

  defp run_game_action(from_state, args) do
    from_state
    |> state_to_module_name
    |> apply(:run, args)
  end

  defp state_to_module_name(state) when is_atom(state) do
    suffix = Atom.to_string(state) |> Macro.camelize()
    String.to_atom("Elixir.CLI." <> suffix)
  end

  defp player_list_to_string(list) do
    case length(list) do
      0 -> ""
      1 -> "#{Enum.at(list, 0)}"
      2 -> "#{Enum.at(list, 0)} and #{Enum.at(list, 1)}"
      cnt -> "#{Enum.at(list, 0)}, #{Enum.at(list, 1)} and #{cnt - 2} others"
    end
  end
end
