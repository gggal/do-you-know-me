defmodule GuessQuestion do
  @behaviour Screen
  @moduledoc """
  This module represents the part of a level that asks the user to give an answer to a question
  for themselves. This part should exist for every level.
  """

  @doc """
  Shows information about other's guess for the current's user question from the previous level.
  It doesn't show anything if it's the first level.
  """
  @impl Screen
  def show(other_user) do
    Client.Application.get_to_guess(other_user) |> elem(0) |> CLI.print_question()
  end

  @doc """
  Makes the user guess other player's answer and answer another question themselves.
  """
  @impl Screen
  def prompt_and_read_input(other_user) do
    CLI.read_answer("Try to guess #{other_user}'s answer:\n")
  end

  @doc """
  Completes current level by showing if their guess to the prev level question was correct,
  making the user to guess other's answer to this level question, making user to answer a
  question for themselves.
  """
  @impl Screen
  def run(other_user) do
    if Client.Application.get_to_guess(other_user) != nil do
      show(other_user)
      correct = Client.Application.get_to_guess(other_user) |> elem(0) |> CLI.print_question()
      guess = CLI.loop_until_correct_input(fn -> prompt_and_read_input(other_user) end)
      Client.Application.give_guess(other_user, guess)

      case guess == correct do
        true -> IO.puts("Your answer was correct.")
        false -> IO.puts("Your answer was incorrect. #{other_user}'s answer was #{correct}")
      end
    end
    transition(other_user)
  end

  @doc """
  Waits for the other person in order to proceed with the next level.
  """
  @impl Screen
  def transition(other_user) do
    {:ok, fn -> SeeQuestion.run(other_user) end}
  end
end
