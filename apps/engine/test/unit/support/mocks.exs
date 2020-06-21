defmodule DummyUser do
  @behaviour User

  def exists?(_), do: true
  def insert(_, _), do: true
  def get_password(_), do: {:ok, "password"}
  def delete(_), do: true
  def all(), do: []
end

defmodule DummyGame do
  @behaviour Game

  def exists?(_, _), do: true
  def insert(_, _, _), do: true
  def start(_, _, _), do: true
  def all_related(_), do: ["username3"]
  def get_score(_, _), do: {:ok, 1}
  def get_old_question(_, _), do: {:ok, 0}
  def get_question(_, _), do: {:ok, 0}
  def get_turn(_, _), do: {:ok, "username2"}
  def answer_question(_, _, _), do: true
  def guess_question(_, _, _), do: true
end

defmodule DummyInvitation do
  @behaviour Invitation

  def exists?(_, _), do: true
  def insert(_, _), do: true
  def delete(_, _), do: true
  def get_all_for(_), do: {:ok, ["username2"]}
end

defmodule DummyQuestion do
  @behaviour Question

  def get_question_number(_), do: {:ok, 0}
  def get_question_answer(_), do: {:ok, "a"}
  def get_question_guess(_), do: {:ok, "b"}
  def set_question_number(_, _), do: true
  def set_question_answer(_, _), do: true
  def set_question_guess(_, _), do: true
end

defmodule DummyScore do
  @behaviour Score

  def get_hits(_), do: {:ok, 1}
  def get_misses(_), do: {:ok, 3}
  def set_hits(_, _), do: true
  def set_misses(_, _), do: true
end

defmodule DummyClient do
  @behaviour Client.Behaviour

  def cast_invitation(_, _), do: :ok
  def cast_related(_, _), do: :ok
  def cast_to_answer(_, _, _), do: :ok
  def cast_to_guess(_, _, _, _), do: :ok
  def cast_to_see(_, _, _, _, _), do: :ok
end

defmodule DummyServer do
  @behaviour Server.Behaviour

  def register(_, _), do: :ok
  def login(_, _), do: :ok
  def unregister(_), do: :ok
  def list_users(), do: {:ok, []}
  def invite(_), do: :ok
  def accept(_), do: :ok
  def decline(_), do: :ok
  def answer_question(_, _), do: :ok
  def guess_question(_, _), do: :ok
  def get_score(_), do: {:ok, 50.0, 50.0}
  def get_turn(_), do: {:ok, true}
end
