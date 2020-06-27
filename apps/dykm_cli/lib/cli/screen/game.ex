defmodule CLI.Game do
  @behaviour CLI.Screen

  alias Client.Worker, as: Client
  alias CLI.Util

  @moduledoc """
  This module represents a game in progress between the current user and another player of choice.
  A level contains a sequence of 3 questions for each user. When a user passes a level, another screen is
  not shown, it stays on this screen and waits for the other user's response instead.
  """
  require Logger

  @doc """
  Completes current level by showing if their guess to the prev level question was correct,
  making the user to guess other's answer to this level question, making user to answer a
  question for themselves.
  """
  @impl CLI.Screen
  def run(other_user) do
    play(other_user)

    {:back, []}
  end

  def play(other_user) do
    with {:ok, false} <- Client.get_turn(other_user) do
      print_hold_msg(other_user)
    end

    case wait_for_event(other_user) do
      :back ->
        :back

      _ ->
        level(other_user)
        play(other_user)
    end
  end

  def wait_for_event(other_user) do
    parent = self()

    check_back =
      spawn(fn ->
        IO.gets("")
        send(parent, :back)
      end)

    check_custom_event = spawn(fn -> ready(parent, other_user) end)

    receive do
      event ->
        Process.exit(check_back, :kill)
        Process.exit(check_custom_event, :kill)
        event
    end
  end

  defp ready(pid, other_user) do
    :timer.sleep(1_000)
    {:ok, turn} = Client.get_turn(other_user)

    if turn do
      send(pid, :ready)
    else
      ready(pid, other_user)
    end
  end

  defp show_to_answer(other_user, q) do
    Util.print_question(q)

    Util.loop_until_correct_input(fn ->
      Util.read_answer("Answer the question from #{other_user}: \n")
    end)
    |> (fn a -> Client.give_answer(other_user, a) end).()
  end

  defp show_to_guess(other_user, {q, correct}) do
    Util.print_question(q)

    guess =
      Util.loop_until_correct_input(fn ->
        Util.read_answer("Try to guess #{other_user}'s answer: \n")
      end)

    Client.give_guess(other_user, guess)

    if guess == correct do
      IO.puts("\nYour answer was correct!\n")
    else
      IO.puts("\nYour answer was incorrect. #{other_user}'s answer was #{correct}\n")
    end
  end

  defp show_to_see(other_user, {q, ans, guess}) when ans == guess do
    IO.puts(
      "#{other_user} guessed correctly! You answered #{ans} on the previous level.\n" <>
        "Question was: \n"
    )

    Util.print_question(q)
  end

  defp show_to_see(other_user, {q, ans, guess}) do
    IO.puts(
      "#{other_user} failed. You answered #{ans} on the previous level, #{other_user} guessed #{
        guess
      }.\n" <> "Question was: "
    )

    Util.print_question(q)
  end

  defp level(other_user) do
    with {:ok, question_details} <- Client.get_to_see(other_user) do
      show_to_see(other_user, question_details)
      :timer.sleep(500)
      IO.gets("Press enter to proceed.")
      Util.print_separator()
    end

    with {:ok, question_details} <- Client.get_to_guess(other_user) do
      show_to_guess(other_user, question_details)
      :timer.sleep(500)
      Util.print_separator()
    end

    with {:ok, question} <- Client.get_to_answer(other_user) do
      show_to_answer(other_user, question)
      :timer.sleep(500)
      Util.print_separator()
    end

    IO.puts("Your input was send to the server.\n")
  end

  defp print_hold_msg(other_user) do
    IO.puts(
      "It's #{other_user}'s turn to play..." <>
        "If you don't want to wait, press enter to go back.\n"
    )

    Util.print_separator()
  end
end
