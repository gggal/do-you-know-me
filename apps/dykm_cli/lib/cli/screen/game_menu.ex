defmodule CLI.GameMenu do
  @behaviour Screen
  @moduledoc """
  Play menu is the screen that shows the user all users they've played with and gives them the chance to
  continue a game.
  """

  require Logger

  @doc """
  Continue a game with another player.
  """
  @impl Screen
  def run() do
    IO.puts("Users you've started a game with:\n")

    with {:ok, users} <- Client.Worker.list_related() do
      users
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

  defp user_choice_to_move("back"), do: {:back, []}
  defp user_choice_to_move(other_user), do: {:choose, [other_user]}
end
