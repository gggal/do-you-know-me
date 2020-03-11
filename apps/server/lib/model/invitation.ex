defmodule Server.Invitation do
  use Ecto.Schema

  schema "invitations" do
    field(:from, :string)
    field(:to, :string)
  end
end
