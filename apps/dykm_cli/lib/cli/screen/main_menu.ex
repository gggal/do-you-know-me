defmodule CLI.MainMenu do
  @behaviour CLI.Screen
  @moduledoc """
  The main screen acts as an entry point for the game functionality. This
  is the screen every other screen can go back to.
  """

  @doc """
  Reads player's choice and proceeds with the next screen.
  """
  @impl CLI.Screen
  def run() do
    IO.puts("Main menu:")

    ["play", "invite", "my invitations", "my scores", "exit"]
    |> CLI.Util.print_menu()
    |> CLI.Util.choose_menu_option()
    |> user_choice_to_move()
  end

  def user_choice_to_move("play"), do: {:play, []}
  def user_choice_to_move("invite"), do: {:invite, []}
  def user_choice_to_move("my invitations"), do: {:get_invites, []}
  def user_choice_to_move("my scores"), do: {:get_scores, []}
  def user_choice_to_move("exit"), do: {:exit, []}
end
