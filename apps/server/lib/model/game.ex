defmodule Server.Game do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "games" do
    field(:user1, :string, primary_key: true)
    field(:user2, :string, primary_key: true)
    field(:question1, :integer)
    field(:question2, :integer)
    field(:score1, :integer)
    field(:score2, :integer)
  end

  def changeset(game, params \\ %{}) do
    game
    |> cast(params, [:user1, :user2, :question1, :question2])
    |> validate_required([:user1, :user2])
    |> unique_constraint(:games_pkey, name: :games_pkey)
    |> foreign_key_constraint(:user1, name: :games_user1_fkey)
    |> foreign_key_constraint(:user2, name: :games_user2_fkey)
    |> foreign_key_constraint(:question1, name: :questions_question1_fkey)
    |> foreign_key_constraint(:question2, name: :questions_question2_fkey)
    |> foreign_key_constraint(:score1, name: :scores_score1_fkey)
    |> foreign_key_constraint(:score2, name: :scores_score2_fkey)
  end

  def exists?(user1, user2) do
    with {first, sec} <- reorder(user1, user2) do
      case Server.Game |> DB.Repo.get_by(%{user1: first, user2: sec}) do
        nil -> false
        _ -> true
      end
    end
  end

  def insert(user1, user2) do
    {q1_id, q2_id, s1_id, s2_id} = insert_questions_and_scores()

    with {first, sec} <- reorder(user1, user2) do
      changeset(%Server.Game{}, %{
        user1: first,
        user2: sec,
        question1: q1_id,
        question2: q2_id,
        score1: s1_id,
        score2: s2_id
      })
      |> DB.Repo.insert()
      |> Server.Util.changeset_to_bool()
    end
  end

  def get_score({user1, user2} = game_id, score_for) do
    cond do
      ordered?(user1, user2) and score_for == user1 -> get_score_helper(game_id, true)
      ordered?(user1, user2) -> get_score_helper(game_id, false)
      score_for == user1 -> get_score_helper({user2, user1}, false)
      true -> get_score_helper({user2, user1}, true)
    end
  end

  defp get_score_helper({user1, user2}, first) do
    case Server.Game |> DB.Repo.get_by(%{user1: user1, user2: user2}) do
      nil -> :err
      %{score1: s1, score2: s2} -> if first, do: {:ok, s1}, else: {:ok, s2}
    end
  end

  def get_question({user1, user2} = game_id, question_for) do
    cond do
      ordered?(user1, user2) and question_for == user1 -> get_question_helper(game_id, true)
      ordered?(user1, user2) -> get_question_helper(game_id, false)
      question_for == user1 -> get_question_helper({user2, user1}, false)
      true -> get_question_helper({user2, user1}, true)
    end
  end

  defp get_question_helper({user1, user2}, first) do
    case Server.Game |> DB.Repo.get_by(%{user1: user1, user2: user2}) do
      nil -> :err
      %{question1: q1, question2: q2} -> if first, do: {:ok, q1}, else: {:ok, q2}
    end
  end

  defp insert_questions_and_scores do
    {:ok, %{id: q1_id}} = %Server.Question{} |> DB.Repo.insert()
    {:ok, %{id: q2_id}} = %Server.Question{} |> DB.Repo.insert()
    {:ok, %{id: s1_id}} = %Server.Score{} |> DB.Repo.insert()
    {:ok, %{id: s2_id}} = %Server.Score{} |> DB.Repo.insert()

    {q1_id, q2_id, s1_id, s2_id}
  end

  defp reorder(user1, user2) when user1 > user2, do: {user2, user1}
  defp reorder(user1, user2), do: {user1, user2}

  defp ordered?(user1, user2), do: user1 < user2
end
