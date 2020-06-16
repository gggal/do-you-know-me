defmodule Game do
  @callback exists?(String.t(), String.t()) :: boolean()
  @callback insert(String.t(), String.t(), String.t()) :: boolean()
  @callback start(String.t(), String.t(), String.t()) :: boolean()
  @callback all_related(String.t()) :: [String.t()]
  @callback get_score({String.t(), String.t()}, String.t()) :: :err | {:ok, integer()}
  @callback get_question({String.t(), String.t()}, String.t()) :: :err | {:ok, integer()}
  @callback get_old_question({String.t(), String.t()}, String.t()) :: :err | {:ok, integer()}
  @callback get_turn(String.t(), String.t()) :: :err | {:ok, String.t()}
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
    field(:old_question1, :integer)
    field(:question2, :integer)
    field(:old_question2, :integer)
    field(:score1, :integer)
    field(:score2, :integer)
    field(:turn, :boolean)
  end

  def changeset(game, params) do
    all_columns = [
      :user1,
      :user2,
      :question1,
      :question2,
      :old_question1,
      :old_question2,
      :score1,
      :score2,
      :turn
    ]

    game
    |> cast(params, all_columns)
    |> validate_required([:user1, :user2, :turn])
    |> unique_constraint(:games_pkey, name: :games_pkey)
    |> foreign_key_constraint(:user1, name: :games_user1_fkey)
    |> foreign_key_constraint(:user2, name: :games_user2_fkey)
    |> foreign_key_constraint(:question1, name: :games_question1_fkey)
    |> foreign_key_constraint(:question2, name: :games_question2_fkey)
    |> foreign_key_constraint(:old_question1, name: :games_old_question1_fkey)
    |> foreign_key_constraint(:old_question2, name: :games_old_question2_fkey)
    |> foreign_key_constraint(:score1, name: :games_score1_fkey)
    |> foreign_key_constraint(:score2, name: :games_score2_fkey)
  end

  def exists?(user1, user2) do
    with {first, sec} <- reorder({user1, user2}) do
      case Server.Game |> DB.Repo.get_by(%{user1: first, user2: sec}) do
        nil -> false
        _ -> true
      end
    end
  end

  def insert(user1, user2, turn) when turn == user1 or turn == user2 do
    case DB.Repo.transaction(fn ->
           with {:ok, %{id: q1_id}} = %Server.Question{} |> DB.Repo.insert(),
                {:ok, %{id: q2_id}} = %Server.Question{} |> DB.Repo.insert(),
                {:ok, %{id: s1_id}} = %Server.Score{} |> DB.Repo.insert(),
                {:ok, %{id: s2_id}} = %Server.Score{} |> DB.Repo.insert(),
                {first, sec} <- reorder({user1, user2}) do
             if not insert_game_helper(first, sec, q1_id, q2_id, s1_id, s2_id, turn) do
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

  def insert(user1, user2, turn) do
    Logger.error("Failed to start game, reason:
    Turn #{turn} is neighter of the two users #{user1} and #{user2}.")
    false
  end

  def start(user1, user2, starts_first) do
    case DB.Repo.transaction(fn ->
           if not Server.Invitation.delete(user1, user2) do
             DB.Repo.rollback(:invitation_deletion_failed)
           end

           if not insert(user1, user2, starts_first) do
             DB.Repo.rollback(:game_insertion_failed)
           end

           {:ok, q1} = get_question({user1, user2}, user1)
           {:ok, q2} = get_question({user1, user2}, user2)

           if not Server.Question.set_question_number(q1, random_question()) do
             DB.Repo.rollback(:question_1_update_failed)
           end

           if not Server.Question.set_question_number(q2, random_question()) do
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

  def get_old_question({user1, _} = game_id, user1) do
    get_old_question_helper(reorder(game_id), ordered?(game_id))
  end

  def get_old_question({_, user2} = game_id, user2) do
    get_old_question_helper(reorder(game_id), not ordered?(game_id))
  end

  def get_old_question({_, _}, _), do: :err

  def get_turn(user1, user2) when not is_nil(user1) and not is_nil(user2) do
    with {first, sec} <- reorder({user1, user2}) do
      case Server.Game |> DB.Repo.get_by(%{user1: first, user2: sec}) do
        nil -> :err
        %{turn: turn} -> {:ok, if(turn, do: sec, else: first)}
      end
    end
  end

  def get_turn(_, _), do: :err

  def answer_question(game_id, user1, answer) do
    case DB.Repo.transaction(fn ->
           with {:ok, q_id} when not is_nil(q_id) <- get_question(game_id, user1),
                {:ok, old_q_id} when not is_nil(old_q_id) <- get_old_question(game_id, user1) do
             #  the old question will become the current one, so set a random question
             #  and null out answer and guess

             if not Question.set_question_number(old_q_id, random_question()) do
               DB.Repo.rollback(:question_num_update_failed)
             end

             if not Question.set_question_answer(old_q_id, nil) do
               DB.Repo.rollback(:question_num_update_failed)
             end

             if not Question.set_question_guess(old_q_id, nil) do
               DB.Repo.rollback(:question_num_update_failed)
             end

             #  the new question will become the old one

             if not Question.set_question_answer(q_id, answer) do
               DB.Repo.rollback(:question_answer_update_failed)
             end

             if not Question.set_question_guess(q_id, nil) do
               DB.Repo.rollback(:question_guess_update_failed)
             end

             if not swap_questions(game_id, user1) do
               DB.Repo.rollback(:swapping_questions_failed)
             end

             # alternate turn value
             if not switch_turn(game_id) do
               DB.Repo.rollback(:turn_switch_failed)
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
           with {:ok, q_id} when not is_nil(q_id) <- get_old_question(game_id, user1),
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

  defp get_old_question_helper({nil, _}, _), do: :err
  defp get_old_question_helper({_, nil}, _), do: :err

  defp get_old_question_helper({user1, user2}, first) do
    case Server.Game |> DB.Repo.get_by(%{user1: user1, user2: user2}) do
      nil -> :err
      %{old_question1: q1, old_question2: q2} -> if first, do: {:ok, q1}, else: {:ok, q2}
    end
  end

  defp switch_turn({nil, _}), do: :err
  defp switch_turn({_, nil}), do: :err

  defp switch_turn({user1, user2}) do
    with game when not is_nil(game) <- DB.Repo.get_by(Server.Game, %{user1: user1, user2: user2}) do
      %{turn: curr_turn} = game

      game
      |> changeset(%{turn: not curr_turn})
      |> DB.Repo.update()
      |> Server.Util.changeset_to_bool()
    else
      nil -> :err
    end
  end

  defp swap_questions({user1, user2}, user1) do
    with game when not is_nil(game) <- DB.Repo.get_by(Server.Game, %{user1: user1, user2: user2}) do
      %{question1: q1_id, old_question1: old_q1_id} = game

      updated =
        if is_nil(old_q1_id) do
          %{question1: random_question(), old_question1: q1_id}
        else
          %{question1: old_q1_id, old_question1: q1_id}
        end

      game
      |> changeset(updated)
      |> DB.Repo.update()
      |> Server.Util.changeset_to_bool()
    else
      nil -> false
    end
  end

  defp swap_questions({user1, user2}, user2) do
    with game when not is_nil(game) <- DB.Repo.get_by(Server.Game, %{user1: user2, user2: user1}) do
      %{question2: q1_id, old_question2: old_q1_id} = game

      updated =
        if is_nil(old_q1_id) do
          %{question2: random_question(), old_question2: q1_id}
        else
          %{question2: old_q1_id, old_question2: q1_id}
        end

      game
      |> changeset(updated)
      |> DB.Repo.update()
      |> Server.Util.changeset_to_bool()
    else
      nil -> false
    end
  end

  defp insert_game_helper(user1, user2, q1, q2, s1, s2, turn) do
    changeset(%Server.Game{}, %{
      user1: user1,
      user2: user2,
      question1: q1,
      question2: q2,
      score1: s1,
      score2: s2,
      turn: turn == user2
    })
    |> DB.Repo.insert()
    |> Server.Util.changeset_to_bool()
  end

  defp reorder({user1, user2}) when user1 > user2, do: {user2, user1}
  defp reorder({user1, user2}), do: {user1, user2}

  defp ordered?({user1, user2}), do: user1 < user2

  defp random_question, do: :rand.uniform(Server.Worker.questions_count())
end
