defmodule Client.State do
  @moduledoc """
  This module represents a client's inner state. It consists of the following data:
    - client's username
    - invitations - list of users that have sent an invitation
    - to_guess - all questions waiting to be guessed, the correct answer, the question and other
    client's username
    - to_answer - all questions waiting to be answered, the question and other client's username
    - to_see - all guessed questions, the guess, the correct answer, the question and other
    client's username
  """

  alias __MODULE__

  @type t :: %State{}

  @enforce_keys [:username, :invitations, :to_guess, :to_answer, :to_see]
  defstruct [:username, :invitations, :to_guess, :to_answer, :to_see]

  def new() do
    %State{username: nil, invitations: MapSet.new(), to_guess: %{}, to_answer: %{}, to_see: %{}}
  end

  def set_username(state = %State{}, name), do: Map.put(state, :username, name)

  def get_username(%State{username: name}), do: name

  def put_to_guess(state = %State{to_guess: questions}, other_user, question) do
    %{state | to_guess: Map.put(questions, other_user, question)}
  end

  def remove_to_guess(state = %State{to_guess: questions}, other_user) do
    %{state | to_guess: Map.delete(questions, other_user)}
  end

  def get_to_guess(%State{to_guess: questions}, other_user) do
    Map.get(questions, other_user)
  end

  def get_all_to_guess(%State{to_guess: questions}), do: Map.keys(questions)

  def put_to_answer(state = %State{to_answer: questions}, other_user, question) do
    %{state | to_answer: Map.put(questions, other_user, question)}
  end

  def remove_to_answer(state = %State{to_answer: questions}, other_user) do
    %{state | to_answer: Map.delete(questions, other_user)}
  end

  def get_to_answer(%State{to_answer: questions}, other_user) do
    Map.get(questions, other_user)
  end

  def get_all_to_answer(%State{to_answer: questions}), do: Map.keys(questions)

  def put_to_see(state = %State{to_see: questions}, other_user, question) do
    %{state | to_see: Map.put(questions, other_user, question)}
  end

  def remove_to_see(state = %State{to_see: questions}, other_user) do
    %{state | to_see: Map.delete(questions, other_user)}
  end

  def get_to_see(%State{to_see: questions}, other_user) do
    Map.get(questions, other_user)
  end

  def get_all_to_see(%State{to_see: questions}), do: Map.keys(questions)

  def get_invitations(%State{invitations: from_users}), do: from_users

  def add_invitation(state = %State{invitations: from_users}, user) do
    %{state | invitations: MapSet.put(from_users, user)}
  end

  def remove_invitation(state = %State{invitations: from_users}, user) do
    %{state | invitations: MapSet.delete(from_users, user)}
  end
end
