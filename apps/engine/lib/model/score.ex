defmodule Score do
  @callback get_hits(integer()) :: {:ok, integer()} | :err
  @callback get_misses(integer()) :: {:ok, integer()} | :err
  @callback set_hits(integer(), integer()) :: boolean()
  @callback set_misses(integer(), integer()) :: boolean()
end

defmodule Server.Score do
  @behaviour Score

  use Ecto.Schema
  import Ecto.Changeset

  schema "scores" do
    field(:hits, :integer)
    field(:misses, :integer)
  end

  def changeset(score, params) do
    score
    |> cast(params, [:id, :hits, :misses])
    |> validate_required([:id, :hits, :misses])
    |> unique_constraint(:scores_pkey, name: :scores_pkey)
    |> validate_number(:hits, greater_than_or_equal_to: 0)
    |> validate_number(:misses, greater_than_or_equal_to: 0)
  end

  def get_hits(nil), do: :err

  def get_hits(score_id) do
    case Server.Score |> DB.Repo.get(score_id) do
      nil -> :err
      %{hits: hits} -> {:ok, hits}
    end
  end

  def get_misses(nil), do: :err

  def get_misses(score_id) do
    case Server.Score |> DB.Repo.get(score_id) do
      nil -> :err
      %{misses: misses} -> {:ok, misses}
    end
  end

  def set_hits(nil, _), do: false

  def set_hits(score_id, hits) do
    case Server.Score |> DB.Repo.get(score_id) do
      nil ->
        false

      record ->
        changeset(record, %{hits: hits})
        |> DB.Repo.update()
        |> Server.Util.changeset_to_bool()
    end
  end

  def set_misses(nil, _), do: false

  def set_misses(score_id, misses) do
    case Server.Score |> DB.Repo.get(score_id) do
      nil ->
        false

      record ->
        changeset(record, %{misses: misses})
        |> DB.Repo.update()
        |> Server.Util.changeset_to_bool()
    end
  end
end
