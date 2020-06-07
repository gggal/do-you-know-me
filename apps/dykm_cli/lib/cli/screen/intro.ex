defmodule Intro do
  @behaviour Screen
  @moduledoc """
  The main screen acts as an entry point for the game functionality. This
  is the screen every other screen can go back to.
  """

  @doc """
  Prints the menu.
  """
  @impl Screen
  def show() do
    IO.puts("Available actions:\n
        1) log in
        2) register
        3) exit\n")
  end

  @doc """
  Makes user choose another screen by inputing a number.
  """
  @impl Screen
  def prompt_and_read_input() do
    user_input = CLI.read_format_int("Choose a number: ")

    case user_input do
      valid when valid > 0 and valid <= 3 ->
        {:ok, valid}

      _invalid ->
        {:err, "Choose a number between 1 and 3."}
    end
  end

  @doc """
  Reads user's choice and proceeds with the next screen.
  """
  @impl Screen
  def run() do
    show()

    CLI.loop_until_correct_input(&prompt_and_read_input/0)
    |> transition
  end

  @doc """
  Transitions to the next screen depending on the user's choice.
  """
  @impl Screen
  def transition(user_input) do
    case user_input do
      1 -> {:ok, &Login.run/0}
      2 -> {:ok, &Register.run/0}
      3 -> :exit
      _ -> {:err, "Invalid user input in main menu"}
    end
  end
end
