defmodule PlayMenu do
  @behaviour Screen
  @moduledoc """
  Play menu is the screen that shows the user all users they've played with and gives them the chance to
  continue a game.
  """

  alias Client.Worker, as: Client

  @doc """
  Displays all players the user has started a game with
  """
  @impl Screen
  def show() do
    IO.puts("Users you've started a game with:\n")

    Client.list_related()
    |> Enum.concat(["back"])
    |> Enum.with_index(1)
    |> Enum.map(fn {user, idx} -> "        #{idx}: #{user}\n" end)
    |> Enum.join()
    |> IO.puts()
  end

  @doc """
  Makes user to choose a player to play with. Returns their username or apropariate error.
  """
  @impl Screen
  def prompt_and_read_input() do
    user_input = CLI.read_format_int("Choose a user to start playing with: ")
    all_related = Client.list_related()

    case all_related |> Enum.concat(["back"]) |> CLI.read_input_menu(user_input) do
      nil -> {:err, "Choose a number between 1 and #{Enum.count(all_related)}."}
      res -> {:ok, res}
    end
  end

  @doc """
  Continue a game with another player.
  """
  @impl Screen
  def run() do
    show()

    CLI.loop_until_correct_input(&prompt_and_read_input/0)
    |> transition()
  end

  @doc """
  Proceeds with play screen for the chosen player.
  """
  @impl Screen
  def transition("back") do
    {:ok, &MainMenu.run/0}
  end

  @impl Screen
  def transition(other_user) do
    {:ok, fn -> Game.run(other_user) end}
  end
end
