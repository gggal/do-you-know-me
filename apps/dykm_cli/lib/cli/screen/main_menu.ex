defmodule CLI.MainMenu do
  @behaviour Screen
  @moduledoc """
  The main screen acts as an entry point for the game functionality. This
  is the screen every other screen can go back to.
  """

  # @doc """
  # Prints the menu.
  # """

  # @impl Screen
  # def show() do
  #   IO.puts("Main menu:\n
  #       1) play
  #       2) invite
  #       3) my invitations
  #       4) my scores
  #       5) exit\n")
  # end

  @doc """
  Makes user choose another screen by inputing a number.
  """

  # @impl Screen
  # def prompt_and_read_input() do
  #   user_input = CLI.read_format_int("Choose a number: ")

  #   case user_input do
  #     valid when valid > 0 and valid <= 5 ->
  #       {:ok, valid}

  #     _invalid ->
  #       {:err, "Choose a number between 1 and 5."}
  #   end
  # end

  @doc """
  Reads user's choice and proceeds with the next screen.
  """
  @impl Screen
  def run() do
    IO.puts("Main menu:")

    user_input =
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

  @doc """
  Transitions to the next screen depending on the user's choice.
  """
  # @impl Screen
  # def transition(user_input) do
  #   case user_input do
  #     1 -> {:ok, &PlayMenu.run/0}
  #     2 -> {:ok, &OnlineUsers.run/0}
  #     3 -> {:ok, &InvitationMenu.run/0}
  #     4 -> {:ok, &Scores.run/0}
  #     5 -> :exit
  #     _ -> {:err, "Invalid user input in main menu"}
  #   end
  # end
end
