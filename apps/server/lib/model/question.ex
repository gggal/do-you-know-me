defmodule Server.Question do
  use Ecto.Schema

  schema "questions" do
    field(:question_id, :integer)
    field(:question_num, :integer)
    field(:answer, :string)
    field(:guess, :string)
  end
end
