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
    IO.puts("Your input has been sent to the server. If you don't want to wait
    for #{other_user} to respond, press a key to go back.")
  end

  @doc """
  Makes the user guess other player's answer and answer another question themselves.
  """
  @impl Screen
  def prompt_and_read_input(other_user) do
  end

  @doc """
  Completes current level by showing if their guess to the prev level question was correct,
  making the user to guess other's answer to this level question, making user to answer a
  question for themselves.
  """
  @impl Screen
  def run(other_user) do
    show(other_user)
    :timer.sleep(5_000)
    transition(other_user)
  end

  @doc """
  Waits for the other person in order to proceed with the next level.
  """
  @impl Screen
  def transition(other_user) do

    spawn fn -> IO.gets(""); send(self(), :back) end
    spawn fn -> ready(self(), other_user) end


    receive do
      :back -> {:ok, &MainMenu.run/0}
      :ready -> {:ok, fn -> AnswerQuestion.run(other_user) end}
    end

    # case Client.Application.get_to_answer(other_user) do
    #   nil -> {:ok, &MainMenu.run/0}
    #   _ -> {:ok, fn -> AnswerQuestion.run(other_user) end}
    # end
  end

  defp ready(pid, other_user) do
    :timer.sleep(1_000)
    case Client.Application.get_to_answer(other_user) do
      nil -> send(pid, :ready)
      _ -> ready(pid, other_user)
    end
  end

  #### PRIVATE ####

  # defp ask_to_guess(nil, _), do: :ok

  # defp ask_to_guess({q, ans}, to) do
  #   IO.puts(q)

  #   case read_answer("\nGuess other's answer:\n") do
  #     {:ok, correct} when correct == ans ->
  #       IO.puts("You guessed correctly.")
  #       Client.Application.give_guess(to, correct)

  #     {:ok, wrong} ->
  #       IO.puts("Your guess was wrong. Other's answer is #{ans}")
  #       Client.Application.give_guess(to, wrong)

  #     {:err, _err_msg} ->
  #       IO.puts("TODO should force user to input correct letter")
  #   end
  # end

  # defp ask_to_answer(q, to) do
  #   # IO.puts(q)
  #   CLI.print_question(q)
  #   {:ok, answer} = read_answer("\nAnswer the question for yourself:\n")
  #   Client.Application.give_answer(to, answer)
  #   {:ok, answer}
  # end

  # defp read_answer(message) do
  #   user_input =
  #     IO.gets(message)
  #     |> String.replace("\n", "")
  #     |> String.replace("\r", "")

  #   case user_input do
  #     valid when valid == "a" or valid == "b" or valid == "c" ->
  #       {:ok, valid}

  #     invalid ->
  #       {:err, "Possibles answers are a,b or c. Received #{invalid}"}
  #   end
  # end
end
