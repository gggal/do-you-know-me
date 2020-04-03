defmodule DB.Repo.Migrations.Initialize do
  use Ecto.Migration

  def change do

    create table(:users, primary_key: false) do
      add :username, :string, null: false, primary_key: true
      add :password, :string, null: false
    end

    create table(:invitations, primary_key: false) do
      add :from, references(:users, column: :username, type: :string), primary_key: true
      add :to, references(:users, column: :username, type: :string), primary_key: true
    end

    create table(:questions) do
      add :question_num, :integer
      add :answer, :string, size: 1
      add :guess, :string, size: 1
    end

    create table(:scores) do
      add :hits, :integer, default: 0
      add :misses, :integer, default: 0
    end

    create table(:games, primary_key: false) do
      add :user1, references(:users, column: :username, type: :string), null: false, primary_key: true
      add :user2, references(:users, column: :username, type: :string), null: false, primary_key: true
      add :question1, references(:questions)
      add :question2, references(:questions)
      add :score1, references(:scores)
      add :score2, references(:scores)
    end
  end
end
