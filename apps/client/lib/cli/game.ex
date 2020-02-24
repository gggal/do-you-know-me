defmodule Game do
  @behaviour Screen
  @moduledoc """
  This module represents a game in progress between the current user and another player of choice.
  A level contains a sequence of 3 questions for each user. When a user passes a level, another screen is
  not shown, it stays on this screen and waits for the other user's response instead.
  """

  @doc """
  Shows information about other's guess for the current's user question from the previous level.
  It doesn't show anything if it's the first level.
  """
  @impl Screen
  def show(other_user) do
    IO.puts(
      case Client.Application.get_to_see(other_user) do
        nil -> "Your game with #{other_user} has began.\n"
        {question, answer, guess} -> "Your question on the previous game was \n#{question}\n
      your answer was #{answer}, #{other_user}'s quess is #{guess}"
      end
    )
  end

  @doc """
  Makes the user guess other player's answer and answer another question themselves.
  """
  @impl Screen
  def prompt_and_read_input(other_user) do
    Client.Application.get_to_guess(other_user) |> ask_to_guess(other_user)
    Client.Application.get_to_answer(other_user) |> ask_to_answer(other_user)
  end

  @doc """
  Completes current level by showing if their guess to the prev level question was correct,
  making the user to guess other's answer to this level question, making user to answer a
  question for themselves.
  """
  @impl Screen
  def run(other_user) do
    show(other_user)

    # {first_guess, sec_answer} =
    CLI.loop_until_correct_input(fn -> prompt_and_read_input(other_user) end)

    # case {Client.Application.give_guess(other_user, first_guess),
    #      Client.Application.give_answer(other_user, sec_answer)} do
    #  {true, true} ->
    #    IO.puts(
    #      "Your input have been sent to the server. Please wait for #{other_user}'s response."
    #    )

    #  _ ->
    #    IO.puts("Internal error occured while trying to process your input...")
    # end

    transition(other_user)
  end

  @doc """
  Waits for the other person in order to proceed with the next level.
  """
  @impl Screen
  def transition(other_user) do
    if Client.Application.get_to_answer(other_user) == nil do
      :timer.sleep(100)
      transition(:dummy)
    end

    {:ok, &run/1}
  end

  #### PRIVATE ####

  defp ask_to_guess(nil, _), do: :ok

  defp ask_to_guess({q, ans}, to) do
    IO.puts(q)

    case read_answer("\nGuess other's answer:\n") do
      {:ok, correct} when correct == ans ->
        IO.puts("You guessed correctly.")
        Client.Application.give_guess(to, correct)

      {:ok, wrong} ->
        IO.puts("Your guess was wrong. Other's answer is #{ans}")
        Client.Application.give_guess(to, wrong)

      {:err, _err_msg} ->
        IO.puts("TODO should force user to input correct letter")
    end
  end

  defp ask_to_answer(q, to) do
    # IO.puts(q)
    CLI.print_question(q)
    {:ok, answer} = read_answer("\nAnswer the question for yourself:\n")
    Client.Application.give_answer(to, answer)
    {:ok, answer}
  end

  defp read_answer(message) do
    user_input =
      IO.gets(message)
      |> String.replace("\n", "")
      |> String.replace("\r", "")

    case user_input do
      valid when valid == "a" or valid == "b" or valid == "c" ->
        {:ok, valid}

      invalid ->
        {:err, "Possibles answers are a,b or c. Received #{invalid}"}
    end
  end
end
