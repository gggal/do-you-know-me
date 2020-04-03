defmodule UserBehaviour do
  @callback exists?(String.t()) :: boolean()
  @callback insert(String.t(), String.t()) :: boolean()
end

defmodule Server.User do
  @behaviour UserBehaviour
  @moduledoc """
  This module maps to the Users table. It contains all users and their details.
  """

  use Ecto.Schema
  import Ecto.Changeset
  require Logger

  @primary_key {:username, :string, []}
  schema "users" do
    field(:password, :string)
  end

  @spec changeset(
          {map, map} | %{:__struct__ => atom | %{__changeset__: map}, optional(atom) => any},
          :invalid | %{optional(:__struct__) => none, optional(atom | binary) => any}
        ) :: Ecto.Changeset.t()
  def changeset(user, params \\ %{}) do
    user
    |> cast(params, [:username, :password])
    |> validate_required([:username, :password])
    |> unique_constraint(:username, name: :users_pkey)
    |> validate_format(:username, ~r/^[[:alnum:]]+$/)
    |> validate_format(:username, ~r/.+/)
  end

  def exists?(username) do
    case Server.User |> DB.Repo.get(username) do
      nil -> false
      _ -> true
    end
  end

  def insert(name, password \\ "default_password") do
    changeset(%Server.User{}, %{username: name, password: password})
    |> DB.Repo.insert()
    |> Server.Util.changeset_to_bool()
  end
end
