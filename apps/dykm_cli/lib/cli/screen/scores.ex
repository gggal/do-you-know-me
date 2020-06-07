defmodule Scores do
  @behaviour Screen
  @moduledoc """
  The scores screen shows the current scores for all games.
  """

  alias Client.Worker, as: Client

  @doc """
  Prints the scores.
  """
  @impl Screen
  def show() do
    case Client.get_score() do
      [] ->
        IO.puts("No scores\n")

      ratings ->
        IO.puts("Your scores:\n")

        ratings
        |> Enum.map(fn {other_user, s1, s2} -> "        #{other_user}: #{s1}% #{s2}%\n" end)
        |> Enum.join()
        |> IO.puts()
    end
  end

  @doc """
  No user input needed
  """
  @impl Screen
  def prompt_and_read_input() do
    {:ok, :dummy}
  end

  @doc """
  Prints the scores and goes back to the previous screen.
  """
  @impl Screen
  def run() do
    show()
    transition()
  end

  @doc """
  Reads whatever and goes back to main menu.
  """
  @impl Screen
  def transition(_user_input \\ nil) do
    IO.gets("Press any key to continue...")
    {:ok, &MainMenu.run/0}
  end
end
