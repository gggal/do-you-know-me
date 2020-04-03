defmodule Server.QuestionTest do
  use ExUnit.Case

  alias Server.Question

  defmodule QuestionState do
    use Agent

    def start_link, do: Agent.start_link(fn -> :ok end, name: __MODULE__)
    def get_id, do: Agent.get(__MODULE__, & &1)
    def set_id(id), do: Agent.update(__MODULE__, fn _ -> id end)
  end

  setup_all do
    {:ok, %{id: id}} =
      %Question{question_num: 1, answer: "a", guess: "b"}
      |> DB.Repo.insert()

    QuestionState.start_link()
    QuestionState.set_id(id)
    on_exit(fn -> %Question{id: id} |> DB.Repo.delete() end)
  end

  test "get question number for non-existent question" do
    assert :err == Question.get_question_number(-1)
  end

  test "get question number for question with nil id" do
    assert :err == Question.get_question_number(nil)
  end

  test "get question number for existent question" do
    assert :ok == Question.get_question_number(QuestionState.get_id()) |> elem(0)
  end

  test "get question answer for non-existent question" do
    assert :err == Question.get_question_answer(-1)
  end

  test "get question answer for question with nil id" do
    assert :err == Question.get_question_answer(nil)
  end

  test "get question answer for existent question" do
    assert :ok == Question.get_question_answer(QuestionState.get_id()) |> elem(0)
  end

  test "get question guess for non-existent question" do
    assert :err == Question.get_question_guess(-1)
  end

  test "get question guess for question with nil id" do
    assert :err == Question.get_question_guess(nil)
  end

  test "get question guess for existent question" do
    assert :ok == Question.get_question_guess(QuestionState.get_id()) |> elem(0)
  end

  test "set nil question number" do
    assert true == Question.set_question_number(QuestionState.get_id(), nil)
  end

  test "set negative question number" do
    assert false == Question.set_question_number(QuestionState.get_id(), -1)
  end

  test "set too large question number" do
    assert false ==
             Question.set_question_number(QuestionState.get_id(), Server.Worker.questions_count())
  end

  test "set question number to non-existent question" do
    assert false == Question.set_question_number(-1, 1)
  end

  test "set question number for question with nil question id" do
    assert false == Question.set_question_number(nil, 1)
  end

  test "set valid question number to existent question" do
    random_number = :rand.uniform(Server.Worker.questions_count())
    assert true == Question.set_question_number(QuestionState.get_id(), random_number)
    assert {:ok, random_number} == Question.get_question_number(QuestionState.get_id())
  end

  test "set nil answer" do
    assert true == Question.set_question_answer(QuestionState.get_id(), nil)
  end

  test "set non-a/b/c answer" do
    assert false == Question.set_question_answer(QuestionState.get_id(), "d")
  end

  test "set non-single-digit answer" do
    assert false == Question.set_question_answer(QuestionState.get_id(), "aa")
  end

  test "set empty string answer" do
    assert false == Question.set_question_answer(QuestionState.get_id(), "")
  end

  test "set answer to non-existent question" do
    assert false == Question.set_question_answer(-1, 1)
  end

  test "set answer for question with nil question id" do
    assert false == Question.set_question_answer(nil, "a")
  end

  test "set valid answer to existent question" do
    assert true == Question.set_question_answer(QuestionState.get_id(), "a")
    assert {:ok, "a"} == Question.get_question_answer(QuestionState.get_id())
  end

  #
  test "set nil guess" do
    assert true == Question.set_question_guess(QuestionState.get_id(), nil)
  end

  test "set non-a/b/c guess" do
    assert false == Question.set_question_guess(QuestionState.get_id(), "d")
  end

  test "set non-single-digit guess" do
    assert false == Question.set_question_guess(QuestionState.get_id(), "aa")
  end

  test "set empty string guess" do
    assert false == Question.set_question_guess(QuestionState.get_id(), "")
  end

  test "set guess to non-existent question" do
    assert false == Question.set_question_guess(-1, 1)
  end

  test "set guess for question with nil question id" do
    assert false == Question.set_question_guess(nil, "a")
  end

  test "set valid guess to existent question" do
    assert true == Question.set_question_guess(QuestionState.get_id(), "a")
    assert {:ok, "a"} == Question.get_question_guess(QuestionState.get_id())
  end
end
