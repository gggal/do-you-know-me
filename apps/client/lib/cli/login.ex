defmodule Login do
  @behaviour Screen
  @moduledoc """
  The login screen is the first screen that users see. They need to log in
  (TODO and authenticate) in order to gain access to the game.
  """

  @doc """
  No need for a screen message as the game hasn't started yet.
  """
  @impl Screen
  def show(), do: IO.puts("")

  @doc """
  Reads user's username, removes trailing new line and checks it with the
  server.
  Returns greeting message for success aor reason for failure.
  """
  @impl Screen
  def prompt_and_read_input() do
    username =
      IO.gets("Please enter your name:\n")
      |> String.replace("\n", "")
      |> String.replace("\r", "")

    case Client.Application.register(username) do
      :registered ->
        {:ok, "You successfully logged in! Let's play!"}

      :taken ->
        {:err, "Login failed: this username is taken."}

      :already_registered ->
        {:err, "Login failed: You can't log more than once in a single session."}
    end
  end

  @doc """
  Log user in, proceeds with main menu.
  """
  @impl Screen
  def run() do
    CLI.loop_until_correct_input(&prompt_and_read_input/0)
    |> transition()
  end

  @doc """
  Proceeds with main menu.
  """
  @impl Screen
  def transition(_user_input) do
    {:ok, &MainMenu.run/0}
  end
end
