defmodule CLI do
  @moduledoc """
  This module represents the command line interface
  """

  def main(_args) do
    # options = [switches: [file: :string],aliases: [f: :file]]
    # {opts,_,_}= OptionParser.parse(args, options)
    # IO.inspect opts, label: "Command Line Arguments"
    CLI.start_game()
  end

  @doc """
  Starts the command line interface
  """
  def start_game() do
    print_separator()
    IO.puts("welcome to do_you_know_me command line interface\n")

    curr_screen_fn = &Login.run/0

    loop(curr_screen_fn)
  end

  # Recursively runs chained functions representing different parts of the game
  # depending on user input.
  defp loop(f) do
    print_separator()

    case f.() do
      {:ok, next} -> loop(next)
      :exit -> IO.puts("Exit game")
      {:err, err_msg} -> IO.puts("Game in inconsistent state: " + err_msg)
    end
  end

  @doc """
  Executes a function `f` until it returns {:ok, result}, if it doesn't, err_msg
  is printed to the user.
  `f` is a function that returns either {:ok, result} or {:err, err_msg}
  Returns result
  """
  def loop_until_correct_input(f) do
    case f.() do
      {:ok, res} ->
        res

      {:err, err_msg} ->
        IO.puts("\n")
        IO.puts(err_msg)
        IO.puts("\n")
        loop_until_correct_input(f)
    end
  end

  defp print_separator() do
    IO.puts("\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n")
  end

  def read_format_string(msg) do
    IO.gets(msg)
    |> String.replace("\n", "")
    |> String.replace("\r", "")
  end

  @spec read_format_int(any) :: :error | {integer, binary}
  def read_format_int(msg) do
    case IO.gets(msg) |> Integer.parse() do
      :error -> :err
      res -> elem(res, 0)
    end
  end

  def read_input_menu(_options, :err), do: nil

  def read_input_menu(_options, num) when num <= 0, do: nil

  def read_input_menu(option, num) do
    Enum.at(option, num - 1)
  end

  def print_question(nil), do: IO.puts("nil")

  def print_question({question, a, b, c}) do
    IO.puts(question)
    IO.puts("\n")
    IO.puts("a) " <> a <> "\n")
    IO.puts("b) " <> b <> "\n")
    IO.puts("c) " <> c <> "\n")
  end

  def read_answer(message) do
    user_input =
      IO.gets(message)
      |> String.replace("\n", "")
      |> String.replace("\r", "")

    case user_input do
      valid when valid == "a" or valid == "b" or valid == "c" ->
        {:ok, String.to_atom(valid)}

      invalid ->
        {:err, "Possibles answers are a,b or c. Received #{invalid}"}
    end
  end

end
