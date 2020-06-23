defmodule CLI.UtilTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  alias CLI.Util

  describe "print_menu" do
    test "arg is not a list" do
      catch_error(Util.print_menu(123))
    end

    test "enumerates the options" do
      output = capture_io(fn -> Util.print_menu(["a", "b", "c"]) end)

      assert [["1.", "a"], ["2.", "b"], ["3.", "c"]] ==
               output
               |> String.split("\n")
               |> Enum.map(fn line -> String.split(line) end)
               |> Enum.filter(fn blank_line -> blank_line != [] end)
    end

    test "doesn't print anything if the list is empty" do
      assert capture_io(fn -> Util.print_menu([]) end) == "\n"
    end
  end

  describe "choose_menu_option" do
    test "arg is not a list" do
      catch_error(Util.choose_menu_option(123))
    end

    test "arg is an empty list" do
      catch_error(Util.choose_menu_option([]))
    end

    test "input is not valid int" do
      invalid_input_resp = "Choose a number between 1 and 2."
      input = "a\n1"
      output = capture_io(input, fn -> Util.choose_menu_option(["a", "b"]) end)
      assert String.contains?(output, invalid_input_resp)
    end

    test "user gets prompted with choose message" do
      input = "1\n"
      output = capture_io(input, fn -> Util.choose_menu_option(["a", "b"]) end)
      assert true == String.starts_with?(output, "Choose a number:")
    end

    test "input is negative" do
      invalid_input_resp = "Choose a number between 1 and 2."
      input = "-1\n1"
      output = capture_io(input, fn -> Util.choose_menu_option(["a", "b"]) end)
      assert String.contains?(output, invalid_input_resp)
    end

    test "input is zero" do
      invalid_input_resp = "Choose a number between 1 and 2."
      input = "0\n1"
      output = capture_io(input, fn -> Util.choose_menu_option(["a", "b"]) end)
      assert String.contains?(output, invalid_input_resp)
    end

    test "input exceeds menu size" do
      invalid_input_resp = "Choose a number between 1 and 2."
      input = "3\n1"
      output = capture_io(input, fn -> Util.choose_menu_option(["a", "b"]) end)
      assert String.contains?(output, invalid_input_resp)
    end

    test "returns choosen option" do
      assert "a" ==
               [input: "1", capture_prompt: false]
               |> capture_io(fn -> Util.choose_menu_option(["a", "b"]) |> IO.write() end)
    end
  end

  describe "print_question" do
    test "invalid format question" do
      catch_error(Util.print_question({"1", "2", "3"}))
    end

    test "print question correctly" do
      output = capture_io(fn -> Util.print_question({"q", "a", "b", "c"}) end)

      assert [["q"], ["a)", "a"], ["b)", "b"], ["c)", "c"]] ==
               output
               |> String.split("\n")
               |> Enum.map(fn line -> String.split(line) end)
               |> Enum.filter(fn blank_line -> blank_line != [] end)
    end
  end

  describe "read_answer" do
    test "input is not a/b/c" do
      result =
        capture_io(
          [input: "d", capture_prompt: false],
          fn -> Util.read_answer("") |> IO.write() end
        )

      assert result == "err, Possibles answers are a, b or c. Received d"
    end

    test "message gets printed" do
      output = capture_io("a", fn -> Util.read_answer("my_msg") end)
      assert String.contains?(output, "my_msg")
    end

    test "input is correct" do
      result =
        capture_io(
          [input: "a", capture_prompt: false],
          fn -> Util.read_answer("") |> IO.write() end
        )

      assert result == "ok, a"
    end
  end

  describe "loop_until_correct_input" do
    test "function returns unexpected result" do
      catch_error(Util.loop_until_correct_input(fn -> :ok end))
    end

    test "function returns upon success" do
      assert 1 == Util.loop_until_correct_input(fn -> {:ok, 1} end)
    end
  end
end
