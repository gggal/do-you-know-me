defmodule InvitationMenu do
  @behaviour Screen
  @moduledoc """
  This screen shows all invitations the user has created. Once an invitation
  is accepted/declined it's not showed anymore. (TODO dynamically add new invitations)
  """

  @doc """
  Shows all invitations, enumerated.
  """
  @impl Screen
  def show() do
    IO.puts("Your invitations are:\n")

    Client.Application.get_invitations()
    |> Enum.concat(["back"])
    |> Enum.with_index(1)
    |> Enum.map(fn {user, idx} -> "        #{idx}. #{user}\n" end)
    |> Enum.join()
    |> IO.puts()
  end

  @doc """
  Makes user to choose an invitation to open by choosing a number.
  Returns the sender's username of the chosen invitation.
  """
  @impl Screen
  def prompt_and_read_input() do
    user_input = CLI.read_format_int("Choose a number: ")
    to = Client.Application.get_invitations() |> Enum.count()

    case Client.Application.get_invitations()
         |> Enum.concat(["back"])
         |> CLI.read_input_menu(user_input) do
      nil -> {:err, "Choose a number between 1 and #{to}."}
      res -> {:ok, res}
    end
  end

  @doc """
  Shows invitations, reads input, opens an invitation.
  """
  @impl Screen
  def run() do
    show()

    CLI.loop_until_correct_input(&prompt_and_read_input/0)
    |> transition
  end

  @doc """
  Transitions to invitation screen.
  """
  @impl Screen
  def transition(user_input) do
    case user_input do
      "back" -> {:ok, &MainMenu.run/0}
      _ -> {:ok, fn -> Invitation.run(user_input) end}
    end
  end
end
