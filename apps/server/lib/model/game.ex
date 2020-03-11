defmodule Server.Game do
  use Ecto.Schema

  schema "games" do
    field(:game_id, :integer)
    field(:username1, :string)
    field(:username2, :string)
  end
end
