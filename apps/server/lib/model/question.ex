defmodule Question do
  @callback get_question_number(integer()) :: :err | {:ok, integer()}
  @callback get_question_answer(integer()) :: :err | {:ok, String.t()}
  @callback get_question_guess(integer()) :: :err | {:ok, String.t()}
  @callback set_question_number(integer(), integer()) :: boolean()
  @callback set_question_answer(integer(), String.t()) :: boolean()
  @callback set_question_guess(integer(), String.t()) :: boolean()
end

defmodule Server.Question do
  @behaviour Question

  use Ecto.Schema
  import Ecto.Changeset
  require Logger

  schema "questions" do
    field(:question_num, :integer)
    field(:answer, :string)
    field(:guess, :string)
  end

  def changeset(question, params) do
    question
    |> cast(params, [:id, :question_num, :answer, :guess], empty_values: [nil])
    |> validate_required([])
    |> unique_constraint(:questions_pkey, name: :questions_pkey)
    |> validate_format(:answer, ~r/^[abc]$/)
    |> validate_length(:answer, is: 1)
    |> validate_format(:guess, ~r/^[abc]$/)
    |> validate_length(:guess, is: 1)
    |> validate_inclusion(:question_num, 0..(Server.Worker.questions_count() - 1))
  end

  def get_question_number(nil), do: :err

  def get_question_number(question_id) do
    case Server.Question |> DB.Repo.get(question_id) do
      nil -> :err
      %{question_num: number} -> {:ok, number}
    end
  end

  def get_question_answer(nil), do: :err

  def get_question_answer(question_id) do
    case Server.Question |> DB.Repo.get(question_id) do
      nil -> :err
      %{answer: answer} -> {:ok, answer}
    end
  end

  def get_question_guess(nil), do: :err

  def get_question_guess(question_id) do
    case Server.Question |> DB.Repo.get(question_id) do
      nil -> :err
      %{guess: guess} -> {:ok, guess}
    end
  end

  def set_question_number(nil, _), do: false

  def set_question_number(question_id, question_num) do
    case Server.Question |> DB.Repo.get(question_id) do
      nil ->
        false

      record ->
        changeset(record, %{question_num: question_num})
        |> DB.Repo.update()
        |> Server.Util.changeset_to_bool()
    end
  end

  def set_question_answer(nil, _), do: false

  def set_question_answer(question_id, answer) do
    case Server.Question |> DB.Repo.get(question_id) do
      nil ->
        false

      record ->
        changeset(record, %{answer: answer})
        |> DB.Repo.update()
        |> Server.Util.changeset_to_bool()
    end
  end

  def set_question_guess(nil, _), do: false

  def set_question_guess(question_id, guess) do
    case Server.Question |> DB.Repo.get(question_id) do
      nil ->
        false

      record ->
        changeset(record, %{guess: guess})
        |> DB.Repo.update()
        |> Server.Util.changeset_to_bool()
    end
  end
end
