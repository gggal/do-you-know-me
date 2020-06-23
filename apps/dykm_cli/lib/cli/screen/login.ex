defmodule CLI.Login do
  @behaviour Screen
  @moduledoc """
  The login screen is the first screen that users see. They need to log in
  mask authenticate in order to gain access to the game.
  """

  @doc """
  Log user in, proceeds with main menu.
  """
  @impl Screen
  def run() do
    CLI.Util.loop_until_correct_input(&prompt_and_read_input/0)
    {:succ, []}
  end

  @doc """
  Reads user's username, removes trailing new line and checks it with the
  server.
  Returns greeting message for success aor reason for failure.
  """
  defp prompt_and_read_input() do
    username = CLI.Util.read_input("Please enter your name: ")
    password = CLI.Util.read_password("Please enter your password: ")

    case Client.Worker.login(username, password) do
      :ok ->
        {:ok, "You successfully logged in! Let's play!"}

      {:err, reason} ->
        {:err, "Login failed: #{reason}"}
    end
  end
end
