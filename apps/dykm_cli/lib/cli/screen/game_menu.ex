defmodule CLI.GameMenu do
  @behaviour CLI.Screen
  @moduledoc """
  Play menu is the screen that shows the user all users they've played with and gives them the chance to
  continue a game.
  """

  require Logger

  @doc """
  Continue a game with another player.
  """
  @impl CLI.Screen
  def run() do
    IO.puts("Users you've started a game with:\n")

    with {:ok, users} <- Client.Worker.list_related() do
      users
      |> Enum.map(&add_waiting_indicator(&1))
      |> Enum.concat(["back"])
      |> CLI.Util.print_menu()
      |> CLI.Util.choose_menu_option()
      |> user_choice_to_move()
    else
      {:err, reason} ->
        Logger.error("Listing users failed: #{reason}")
        IO.puts("Something went wrong. Try again later...\n")
        {:back, []}
    end
  end

  defp add_waiting_indicator(user) do
    with {:ok, true} <- Client.Worker.get_turn(user) do
      user <> "*"
    else
      _ -> user
    end
  end

  defp user_choice_to_move("back"), do: {:back, []}

  defp user_choice_to_move(other_user) do
    {:choose, [remove_indication(other_user)]}
  end

  defp remove_indication(user) do
    if String.ends_with?(user, "*") do
      # removes the asterisk char from the end of the username
      String.slice(user, 0..-2)
    else
      user
    end
  end
end
