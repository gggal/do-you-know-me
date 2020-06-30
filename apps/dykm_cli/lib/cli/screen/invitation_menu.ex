defmodule CLI.InvitationMenu do
  @behaviour CLI.Screen
  @moduledoc """
  This screen shows all invitations the user has created. Once an invitation
  is accepted/declined, it's not showed anymore.
  """

  require Logger

  @doc """
  Shows invitations, reads input, opens an invitation.
  """
  @impl CLI.Screen
  def run() do
    with {:ok, invitations} <- Client.Worker.get_invitations() do
      IO.puts("Your invitations are:\n")

      invitations
      |> Enum.concat(["back"])
      |> CLI.Util.print_menu()
      |> CLI.Util.choose_menu_option()
      |> user_choice_to_move
    else
      {:err, reason} ->
        Logger.error("Fetching invitations failed: #{reason}")
        IO.puts("Something went wrong. Try again later...")
    end
  end

  defp user_choice_to_move(user_input) do
    if user_input == "back" do
      {:back, []}
    else
      {:choose, [user_input]}
    end
  end
end
