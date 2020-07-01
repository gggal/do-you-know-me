defmodule User do
  @callback exists?(String.t()) :: boolean()
  @callback insert(String.t(), String.t()) :: boolean()
  @callback correct_password?(String.t(), String.t()) :: :err | {:ok, boolean()}
  @callback delete(String.t()) :: boolean()
  @callback all() :: [String.t()]
end

defmodule Server.User do
  @behaviour User
  @moduledoc """
  This module maps to the Users table. It contains all users and their details.
  """

  alias Server.Game
  alias Server.Question
  alias Server.Score
  alias Server.Invitation

  use Ecto.Schema
  import Ecto.Changeset
  require Logger
  require Ecto.Query

  @primary_key {:username, :string, []}
  schema "users" do
    field(:password, :string)
  end

  def changeset(user, params) do
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

  def insert(name, password) when is_bitstring(password) and password != "" do
    # hash the password
    %{password_hash: hash} = Bcrypt.add_hash(password)

    changeset(%Server.User{}, %{username: name, password: hash})
    |> DB.Repo.insert()
    |> Server.Util.changeset_to_bool()
  end

  def insert(_, _), do: false

  def correct_password?(name, password) do
    with %{password: hash} <- Server.User |> DB.Repo.get(name),
         {:ok, _} <- Bcrypt.check_pass(%{password_hash: hash}, password) do
      {:ok, true}
    else
      nil -> :err
      _ -> {:ok, false}
    end
  end

  def all do
    Server.User |> DB.Repo.all() |> Enum.map(fn %{username: name} -> name end)
  end

  def delete(name) do
    if exists?(name) do
      case DB.Repo.transaction(fn -> delete_all_user_data(name) end) do
        {:ok, _} ->
          true

        {:err, reason} ->
          Logger.error("Failed to delete user, reason: #{reason}")
          false
      end
    else
      false
    end
  end

  defp delete_all_user_data(name) do
    questions_to_del = users_questions(name)
    scores_to_del = users_scores(name)
    DB.Repo.delete_all(Ecto.Query.from(g in Game, where: g.user1 == ^name or g.user2 == ^name))
    DB.Repo.delete_all(Ecto.Query.from(i in Invitation, where: i.from == ^name or i.to == ^name))
    DB.Repo.delete_all(Ecto.Query.from(q in Question, where: q.id in ^questions_to_del))
    DB.Repo.delete_all(Ecto.Query.from(s in Score, where: s.id in ^scores_to_del))
    DB.Repo.delete_all(Ecto.Query.from(u in Server.User, where: u.username == ^name))
  end

  defp users_questions(name) do
    Ecto.Query.from(g in Game,
      where: g.user1 == ^name or g.user2 == ^name,
      select: [g.question1, g.question2]
    )
    |> DB.Repo.all()
    |> List.flatten()
  end

  defp users_scores(name) do
    Ecto.Query.from(g in Game,
      where: g.user1 == ^name or g.user2 == ^name,
      select: [g.score1, g.score2]
    )
    |> DB.Repo.all()
    |> List.flatten()
  end
end
