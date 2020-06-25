defmodule CLI.Util do
  @doc """
  Prints a screen separator.
  """
  @spec print_separator :: :ok
  def print_separator do
    IO.puts("\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n")
  end

  @doc """
  Enumerates, formats and pretty prints a list of options for the
  player to choose from, then returns back said list.
  """
  @spec print_menu(List.t()) :: List.t()
  def print_menu(menu) when is_list(menu) do
    menu
    |> Enum.with_index(1)
    |> Enum.map(fn {option, idx} -> "        #{idx}. #{option}\n" end)
    |> Enum.join()
    |> IO.puts()

    menu
  end

  @doc """
  Prompts user to choose out of a set of options. Their choice
  must be a number, non-exceeding the menu options count. If the
  input is not in the correct format, the user gets asked
  repeatedly until their answer is accepted.
  The chosen option is returned.
  """
  @spec choose_menu_option(List.t()) :: any()
  def choose_menu_option(menu) when is_list(menu) and length(menu) != 0 do
    loop_until_correct_input(fn -> choose_number(menu) end)
  end

  @spec choose_number(List.t()) :: {:ok, any()} | {:err, String.t()}
  defp choose_number(menu) do
    user_input = read_format_int("Choose a number: ")
    options_count = Enum.count(menu)

    case user_input do
      valid when valid > 0 and valid <= options_count ->
        {:ok, Enum.at(menu, valid - 1)}

      _invalid ->
        {:err, "Choose a number between 1 and #{Enum.count(menu)}."}
    end
  end

  def read_input(msg) do
    IO.gets(msg)
    |> String.replace("\n", "")
    |> String.replace("\r", "")
  end

  def read_password(msg) do
    pid = spawn_link(fn -> hide_input(msg) end)
    to_return = read_input(msg)

    send(pid, :done)

    to_return
  end

  defp hide_input(prompt) do
    receive do
      :done -> IO.write(:standard_error, "\e[2K\r")
    after
      1 ->
        IO.write(:standard_error, "\e[2K\r#{prompt} ")
        hide_input(prompt)
    end
  end

  @spec read_format_int(String.t()) :: :err | integer()
  defp read_format_int(msg) do
    case IO.gets(msg) |> Integer.parse() do
      :error -> :err
      res -> elem(res, 0)
    end
  end

  # def read_input_menu(_options, :err), do: nil

  # def read_input_menu(_options, num) when num <= 0, do: nil

  # def read_input_menu(option, num) do
  #   Enum.at(option, num - 1)
  # end

  # def print_question(nil), do: IO.puts("nil")

  @doc """
  Pretty prints a question.
  """
  @spec print_question({String.t(), String.t(), String.t(), String.t()}) :: :ok
  def print_question({question, a, b, c}) do
    IO.puts(question)
    IO.puts("\n")
    IO.puts("        a) " <> a <> "\n")
    IO.puts("        b) " <> b <> "\n")
    IO.puts("        c) " <> c <> "\n")
  end

  @doc """
  Reads a question answer from the standard input.
  The possible answers are a,b and c.
  """
  @spec read_answer(String.t()) :: {:ok, String.t()} | {:err, String.t()}
  def read_answer(message) do
    user_input =
      IO.gets(message)
      |> String.replace("\n", "")
      |> String.replace("\r", "")

    case user_input do
      valid when valid == "a" or valid == "b" or valid == "c" ->
        {:ok, valid}

      invalid ->
        {:err, "Possibles answers are a, b or c. Received #{invalid}"}
    end
  end

  @doc """
  Executes a function `f` until it returns {:ok, result}, if it doesn't, err_msg
  is printed to the user.
  `f` is a function that returns either {:ok, result} or {:err, err_msg}
  Returns result.
  """
  @spec loop_until_correct_input(fun()) :: any()
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
end
