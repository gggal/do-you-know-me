defmodule Invitation do
  @callback exists?(String.t(), String.t()) :: boolean()
  @callback insert(String.t(), String.t()) :: boolean()
  @callback delete(String.t(), String.t()) :: boolean()
  @callback get_all_for(String.t()) :: :err | {:ok, [Stirng.t()]}
end

defmodule Server.Invitation do
  @behaviour Invitation

  require Ecto.Query
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "invitations" do
    field(:from, :string, primary_key: true)
    field(:to, :string, primary_key: true)
  end

  def changeset(invitation, params) do
    invitation
    |> cast(params, [:from, :to])
    |> validate_required([:from, :to])
    |> unique_constraint(:invitations_pkey, name: :invitations_pkey)
    |> foreign_key_constraint(:from, name: :invitations_from_fkey)
    |> foreign_key_constraint(:to, name: :invitations_to_fkey)
  end

  def exists?(from, to) do
    case Server.Invitation |> DB.Repo.get_by(%{from: from, to: to}) do
      nil -> false
      _ -> true
    end
  end

  def get_all_for(for_user) when is_binary(for_user) do
    {:ok,
     Ecto.Query.from(
       i in Server.Invitation,
       where: i.to == ^for_user,
       select: i.from
     )
     |> DB.Repo.all()}
  end

  def get_all_for(_), do: :err

  def insert(from, to) do
    changeset(%Server.Invitation{}, %{from: from, to: to})
    |> DB.Repo.insert()
    |> Server.Util.changeset_to_bool()
  end

  def delete(from, to) do
    case Server.Invitation |> DB.Repo.get_by(%{from: from, to: to}) do
      nil ->
        false

      instance ->
        changeset(instance, %{from: from, to: to})
        |> DB.Repo.delete()
        |> Server.Util.changeset_to_bool()
    end
  end
end
