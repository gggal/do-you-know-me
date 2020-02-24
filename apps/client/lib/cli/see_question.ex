defmodule SeeQuestion do
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
    {q, ans, guess} = Client.Application.get_to_see(other_user)
    CLI.print_question(q)
    IO.puts("#{other_user} guessed your answer to be #{guess}, it was #{ans}")
  end

  @doc """
  Makes the user guess other player's answer and answer another question themselves.
  """
  @impl Screen
  def prompt_and_read_input(other_user) do
    :ok
  end

  @doc """
  Completes current level by showing if their guess to the prev level question was correct,
  making the user to guess other's answer to this level question, making user to answer a
  question for themselves.
  """
  @impl Screen
  def run(other_user) do
    if Client.Application.get_to_see(other_user) != nil do
      show(other_user)
    end
    transition(other_user)
  end

  @doc """
  Waits for the other person in order to proceed with the next level.
  """
  @impl Screen
  def transition(other_user) do
    {:ok, fn -> Game.run(other_user) end}
  end
end
