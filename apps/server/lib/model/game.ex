defmodule Game do
  @callback exists?(String.t(), String.t()) :: boolean()
  @callback insert(String.t(), String.t()) :: boolean()
  @callback start(String.t(), String.t()) :: boolean()
  @callback all_related(String.t()) :: [String.t()]
  @callback get_score({String.t(), String.t()}, String.t()) :: :err | {:ok, integer()}
  @callback get_question({String.t(), String.t()}, String.t()) :: :err | {:ok, integer()}
  @callback answer_question({String.t(), String.t()}, String.t(), String.t()) :: boolean()
  @callback guess_question({String.t(), String.t()}, String.t(), String.t()) :: boolean()
end

defmodule Server.Game do
  @behaviour Game

  use Ecto.Schema
  import Ecto.Changeset
  require Ecto.Query
  require Logger

  alias Server.Question
  alias Server.Score

  @primary_key false
  schema "games" do
    field(:user1, :string, primary_key: true)
    field(:user2, :string, primary_key: true)
    field(:question1, :integer)
    field(:question2, :integer)
    field(:score1, :integer)
    field(:score2, :integer)
  end

  def changeset(game, params) do
    game
    |> cast(params, [:user1, :user2, :question1, :question2, :score1, :score2])
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
    with {first, sec} <- reorder({user1, user2}) do
      case Server.Game |> DB.Repo.get_by(%{user1: first, user2: sec}) do
        nil -> false
        _ -> true
      end
    end
  end

  def insert(user1, user2) do
    case DB.Repo.transaction(fn ->
           with {:ok, %{id: q1_id}} = %Server.Question{} |> DB.Repo.insert(),
                {:ok, %{id: q2_id}} = %Server.Question{} |> DB.Repo.insert(),
                {:ok, %{id: s1_id}} = %Server.Score{} |> DB.Repo.insert(),
                {:ok, %{id: s2_id}} = %Server.Score{} |> DB.Repo.insert(),
                {first, sec} <- reorder({user1, user2}) do
             if not insert_game_helper(first, sec, q1_id, q2_id, s1_id, s2_id) do
               DB.Repo.rollback(:inserting_game_failed)
             end
           else
             _ -> DB.Repo.rollback(:inserting_metadata_failed)
           end
         end) do
      {:ok, _} ->
        true

      {:error, reason} ->
        Logger.error("Failed to start game, reason: #{reason}")
        false
    end
  end

  def start(user1, user2) do
    case DB.Repo.transaction(fn ->
           if Server.Invitation.delete(user1, user2) == false do
             DB.Repo.rollback(:invitation_deletion_failed)
           end

           if insert(user1, user2) == false do
             DB.Repo.rollback(:game_insertion_failed)
           end

           {:ok, q1} = get_question({user1, user2}, user1)
           {:ok, q2} = get_question({user1, user2}, user2)

           if Server.Question.set_question_number(q1, random_question()) == false do
             DB.Repo.rollback(:question_1_update_failed)
           end

           if Server.Question.set_question_number(q2, random_question()) == false do
             DB.Repo.rollback(:question_2_update_failed)
           end
         end) do
      {:ok, _} ->
        true

      {:error, reason} ->
        Logger.error("Failed to start game, reason: #{reason}")
        false
    end
  end

  def all_related(to) do
    left =
      Ecto.Query.from(g in Server.Game, where: g.user1 == ^to, select: g.user2) |> DB.Repo.all()

    right =
      Ecto.Query.from(g in Server.Game, where: g.user2 == ^to, select: g.user1) |> DB.Repo.all()

    left ++ right
  end

  def get_score({user1, _} = game_id, user1) do
    get_score_helper(reorder(game_id), ordered?(game_id))
  end

  def get_score({_, user2} = game_id, user2) do
    get_score_helper(reorder(game_id), not ordered?(game_id))
  end

  def get_score({_, _}, _), do: :err

  def get_question({user1, _} = game_id, user1) do
    get_question_helper(reorder(game_id), ordered?(game_id))
  end

  def get_question({_, user2} = game_id, user2) do
    get_question_helper(reorder(game_id), not ordered?(game_id))
  end

  def get_question({_, _}, _), do: :err

  def answer_question(game_id, user1, answer) do
    case DB.Repo.transaction(fn ->
           with {:ok, q_id} when not is_nil(q_id) <- get_question(game_id, user1) do
             if Question.set_question_number(q_id, random_question()) == false do
               DB.Repo.rollback(:question_num_update_failed)
             end

             if Question.set_question_answer(q_id, answer) == false do
               DB.Repo.rollback(:question_answer_update_failed)
             end

             if Question.set_question_guess(q_id, nil) == false do
               DB.Repo.rollback(:question_guess_update_failed)
             end
           else
             _ -> DB.Repo.rollback(:obtaining_game_data_fails)
           end
         end) do
      {:ok, _} ->
        true

      {:error, reason} ->
        Logger.error("Failed to answer question, reason: #{reason}")
        false
    end
  end

  def guess_question(game_id, user1, guess) do
    case DB.Repo.transaction(fn ->
           with {:ok, q_id} <- get_question(game_id, user1),
                {:ok, s_id} <- get_score(game_id, user1),
                %{answer: answer} <- DB.Repo.get(Question, q_id),
                %{hits: hits, misses: misses} <- DB.Repo.get(Score, s_id) do
             if Question.set_question_guess(q_id, guess) == false do
               DB.Repo.rollback(:question_guess_update_failed)
             end

             if guess == answer do
               if not Score.set_hits(s_id, hits + 1), do: DB.Repo.rollback(:update_hits_failed)
             else
               if not Score.set_misses(s_id, misses + 1),
                 do: DB.Repo.rollback(:update_misses_failed)
             end
           else
             _ -> DB.Repo.rollback(:obtaining_game_data_fails)
           end
         end) do
      {:ok, _} ->
        true

      {:error, reason} ->
        Logger.error("Failed to answer question, reason: #{reason}")
        false
    end
  end

  defp get_score_helper({nil, _}, _), do: :err
  defp get_score_helper({_, nil}, _), do: :err

  defp get_score_helper({user1, user2}, first) do
    case Server.Game |> DB.Repo.get_by(%{user1: user1, user2: user2}) do
      nil -> :err
      %{score1: s1, score2: s2} -> if first, do: {:ok, s1}, else: {:ok, s2}
    end
  end

  defp get_question_helper({nil, _}, _), do: :err
  defp get_question_helper({_, nil}, _), do: :err

  defp get_question_helper({user1, user2}, first) do
    case Server.Game |> DB.Repo.get_by(%{user1: user1, user2: user2}) do
      nil -> :err
      %{question1: q1, question2: q2} -> if first, do: {:ok, q1}, else: {:ok, q2}
    end
  end

  defp insert_game_helper(user1, user2, q1, q2, s1, s2) do
    changeset(%Server.Game{}, %{
      user1: user1,
      user2: user2,
      question1: q1,
      question2: q2,
      score1: s1,
      score2: s2
    })
    |> DB.Repo.insert()
    |> Server.Util.changeset_to_bool()
  end

  defp reorder({user1, user2}) when user1 > user2, do: {user2, user1}
  defp reorder({user1, user2}), do: {user1, user2}

  defp ordered?({user1, user2}), do: user1 < user2

  defp random_question, do: :rand.uniform(Server.Worker.questions_count())
end
