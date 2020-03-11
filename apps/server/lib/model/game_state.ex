defmodule Server.GameState do
  use Ecto.Schema

  schema "game_states" do
    field(:game_id, :integer)
    field(:turn, :boolean)
    field(:question_1, :integer)
    field(:question_2, :integer)
  end
end
