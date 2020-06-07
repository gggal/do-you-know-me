defmodule Game do
  @behaviour Screen

  alias Client.Worker, as: Client

  @moduledoc """
  This module represents a game in progress between the current user and another player of choice.
  A level contains a sequence of 3 questions for each user. When a user passes a level, another screen is
  not shown, it stays on this screen and waits for the other user's response instead.
  """
  require Logger

  @doc """
  Shows information about other's guess for the current's user question from the previous level.
  It doesn't show anything if it's the first level.
  """
  @impl Screen
  def show(other_user) do
    IO.puts("\nYour input has been sent to the server. If you don't want to wait
    for #{other_user} to respond, press a key to go back.")
  end

  @doc """
  Makes the user guess other player's answer and answer another question themselves.
  """
  @impl Screen
  def prompt_and_read_input(_other_user) do
    {:ok, :dummy}
  end

  @doc """
  Completes current level by showing if their guess to the prev level question was correct,
  making the user to guess other's answer to this level question, making user to answer a
  question for themselves.
  """

  # @impl Screen
  # def run(other_user) do
  #   show(other_user)
  #   transition(other_user)
  # end

  @impl Screen
  def run(other_user) do
    if Client.get_to_answer(other_user) != nil do
      play(other_user)
      IO.puts("Your input was sent to the server.")
    end

    IO.puts(
      "Waiting for #{other_user} to play..." <>
        "If you don't want to wait, press any key to go back."
    )

    transition(other_user)
  end

  def play(other_user) do
    case {Client.get_to_answer(other_user), Client.get_to_guess(other_user),
          Client.get_to_see(other_user)} do
      {nil, _, _} ->
        Logger.error("Something's very wrong!")

      # first level
      {a, nil, nil} ->
        show_to_answer(other_user, a)
        :timer.sleep(500)

      # second level
      {a, b, nil} ->
        show_to_answer(other_user, a)
        :timer.sleep(500)
        separator()
        show_to_guess(other_user, b)

      {a, b, c} ->
        show_to_answer(other_user, a)
        :timer.sleep(500)
        separator()
        show_to_guess(other_user, b)
        :timer.sleep(500)
        separator()
        show_to_see(other_user, c)
    end
  end

  @doc """
  Waits for the other person in order to proceed with the next level.
  """
  @impl Screen
  def transition(other_user) do
    parent = self()

    p1 =
      spawn(fn ->
        IO.gets("")
        send(parent, :back)
      end)

    p2 = spawn(fn -> ready(parent, other_user) end)

    receive do
      :back ->
        # TODO hibernate them or revive/recycle instead of killing
        Process.exit(p1, :kill)
        Process.exit(p2, :kill)
        {:ok, &MainMenu.run/0}

      :ready ->
        # TODO hibernate them or revive/recycle instead of killing
        Process.exit(p1, :kill)
        Process.exit(p2, :kill)
        {:ok, fn -> Game.run(other_user) end}

      other ->
        # TODO hibernate them or revive/recycle instead of killing
        Process.exit(p1, :kill)
        Process.exit(p2, :kill)
        {:err, "Expected :back or :ready message, got #{other}"}
    end
  end

  defp ready(pid, other_user) do
    :timer.sleep(1_000)

    case Client.get_to_answer(other_user) do
      nil -> ready(pid, other_user)
      _ -> send(pid, :ready)
    end
  end

  defp separator() do
    IO.puts("\n__________________________________________________________________\n")
  end

  defp show_to_answer(other_user, q) do
    CLI.print_question(q)

    CLI.loop_until_correct_input(fn ->
      CLI.read_answer("Answer the question from #{other_user}: ")
    end)
    |> (fn a -> Client.give_answer(other_user, a) end).()
  end

  defp show_to_guess(other_user, {q, correct}) do
    CLI.print_question(q)

    guess =
      CLI.loop_until_correct_input(fn ->
        CLI.read_answer("Try to guess #{other_user}'s answer: ")
      end)

    Client.give_guess(other_user, guess)

    case guess == correct do
      true -> IO.puts("\nYour answer was correct!\n")
      false -> IO.puts("\nYour answer was incorrect. #{other_user}'s answer was #{correct}\n")
    end
  end

  defp show_to_see(other_user, {q, ans, guess}) when ans == guess do
    IO.puts(
      "#{other_user} guessed correctly! You answered #{ans} on the previous level.\n" <>
        "Question was: "
    )

    CLI.print_question(q)
  end

  defp show_to_see(other_user, {q, ans, guess}) do
    IO.puts(
      "#{other_user} failed. You answered #{ans} on the previous level, #{other_user} guessed #{
        guess
      }.\n" <> "Question was: "
    )

    CLI.print_question(q)
  end
end
