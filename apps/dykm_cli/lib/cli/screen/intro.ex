defmodule CLI.Intro do
  @behaviour CLI.Screen
  @moduledoc """
  The main screen acts as an entry point for the game functionality.
  It prompts the user to authenticate. Once this is done, user can
  proceed with the game.
  """

  @doc """
  Reads user's choice and proceeds with the next screen.
  """
  @impl CLI.Screen
  def run() do
    IO.puts("Available actions:")

    {
      [:login, :register, :exit]
      |> CLI.Util.print_menu()
      |> CLI.Util.choose_menu_option(),
      []
    }
  end
end
