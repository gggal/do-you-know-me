defmodule CLI.Intro do
  @behaviour CLI.Screen
  @moduledoc """
  The Intro screen is the first screen that users see. They need to
  log in/register in order to gain access to the game.
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
