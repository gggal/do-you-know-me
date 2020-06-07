defmodule TestClient do
  @moduledoc """
  Mock module for CLI testing purposes
  """

  def register(name) do
    case name do
      "registered" -> :registered
      "taken" -> :taken
      "already_registered" -> :already_registered
    end
  end

  def unregister() do
    GenServer.call(:quiz_client, :unregister)
  end

  def get_invitations() do
    GenServer.call(:quiz_client, :see_invitations)
    |> Enum.map(fn {key, _val} -> key end)
  end

  def invite(user) do
    GenServer.cast(:quiz_client, {:invite, user})
  end

  def decline(from) do
    GenServer.cast(:quiz_client, {:decline, from})
  end

  def accept(from) do
    GenServer.cast(:quiz_client, {:accept, from})
  end

  def give_answer(other, answer) do
    GenServer.cast(:quiz_client, {:answer, other, answer})
  end

  def give_guess(other, guess) do
    GenServer.call(:quiz_client, {:guess, other, guess})
  end

  def username() do
    GenServer.call(:quiz_client, :username)
  end

  def get_to_guess(other) do
    GenServer.call(:quiz_client, :get_to_guess) |> Map.get(other, nil)
  end

  def get_to_answer(other) do
    GenServer.call(:quiz_client, :get_to_answer) |> Map.get(other, nil)
  end

  def get_to_see(other) do
    GenServer.call(:quiz_client, :get_to_see) |> Map.get(other, nil)
  end

  def get_rating() do
    GenServer.call(:quiz_client, :get_rating)
  end

  def get_rating(with) do
    GenServer.call(:quiz_client, {:get_rating, with})
  end

  def list_registered() do
    GenServer.call(:quiz_client, :list_registered)
  end

  def list_related() do
    GenServer.call(:quiz_client, :get_related)
  end
end
