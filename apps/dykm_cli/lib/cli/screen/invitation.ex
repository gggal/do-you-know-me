defmodule Invitation do
  @behaviour Screen
  @moduledoc """
  This module represents an open invitation. The user has a choice:
  they can accept or reject the invitation.
  """

  alias Client.Worker, as: Client

  @doc """
  Shows the 2 possibilities (accept/reject).
  """
  @impl Screen
  def show() do
    IO.puts("Accept/decline:
        1) accept
        2) decline
        3) back")
  end

  @doc """
  Makes user to choose either to accept or decline the invitation.
  """
  @impl Screen
  def prompt_and_read_input() do
    user_input = CLI.read_format_int("\nChoose a number: ")

    case user_input do
      valid when valid >= 1 or valid <= 3 ->
        {:ok, valid}

      _invalid ->
        {:err, "Choose 1 to accept and 2 to decline."}
    end
  end

  @doc """
  Removes the invitation by accepting or declining it. Goes back to
  invitations screen.
  """
  @impl Screen
  def run(other_user) do
    show()

    user_input = CLI.loop_until_correct_input(&prompt_and_read_input/0)

    case user_input do
      1 ->
        Client.accept(other_user)
        :timer.sleep(2_000)
        transition(1, other_user)

      2 ->
        Client.decline(other_user)
        transition(:dummy)

      3 ->
        :ok
        transition(:dummy)
    end
  end

  @doc """
  Goes to play screen.
  """
  def transition(1, other_user) do
    {:ok, fn -> Game.run(other_user) end}
  end

  @doc """
  Goes back to invitations screen.
  """
  @impl Screen
  def transition(_user_input) do
    {:ok, &InvitationMenu.run/0}
  end
end
