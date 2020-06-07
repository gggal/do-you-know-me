defmodule Register do
  @behaviour Screen
  @moduledoc """
  The login screen is the first screen that users see. They need to log in
  (TODO and authenticate) in order to gain access to the game.
  """

  alias Client.Worker, as: Client

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
    username = read_name()
    password = read_pass()

    case Client.register(username, password) do
      :ok ->
        {:ok, "You successfully registered! Let's play!"}

      {:err, reason} ->
        {:err, "Registration failed: #{reason}"}
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

  defp read_name do
    IO.gets("Please enter your name: ")
    |> String.replace("\n", "")
    |> String.replace("\r", "")
  end

  defp read_pass do
    IO.gets("Please enter your password: ")
    |> String.replace("\n", "")
    |> String.replace("\r", "")
  end
end
