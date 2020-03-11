defmodule DB.Repo.Migrations.Initialize do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :username, :string, null: false, primary_key: true
      add :password, :string, null: false
    end

    create table(:games) do
      add :username1, references(:users, column: :username, type: :string)
      add :username2, references(:users, column: :username, type: :string)
    end

    create table(:questions) do
      add :question_num, :integer, null: false
      add :answer, :string
      add :guess, :string
    end

    create table(:game_states) do
      add :game_id, references(:games)
      add :turn, :smallint, null: false
      add :question_1, references(:questions)
      add :question_2, references(:questions)
    end

    create table(:invitations, primary_key: false) do
      add :from, references(:users, column: :username, type: :string), primary_key: true
      add :to, references(:users, column: :username, type: :string), primary_key: true
    end

  end
end
