defmodule CLI.AllUsers do
  require Logger
  @behaviour Screen
  @moduledoc """
  This screen shows all online users and gives the user the chance to
  send invitations.
  """

  alias Client.Worker, as: Client

  @doc """
  Shows available users, sends invitations.
  """
  @impl Screen
  def run() do
    IO.puts("Other players:\n\n")

    with {:ok, user_list} <- Client.list_registered() do
      user_list
      |> Enum.concat(["back"])
      |> CLI.Util.print_menu()
      |> invite_until_back()
    else
      {:err, reason} ->
        IO.puts("An error occurred while communicating with the engine.
        Try again later.")
        {:back, []}
    end
  end

  @doc """
  Sends invitations until user decides to go back to main menu
  """
  defp invite_until_back(options) do
    case CLI.Util.choose_menu_option(options) do
      "back" ->
        {:back, []}

      player ->
        case Client.invite(player) do
          :ok ->
            IO.puts("An invitation was sent...\n")
            invite_until_back(options)

          {:err, :not_eligible} ->
            IO.puts("You already invited / are playing with this user.")
            invite_until_back(options)

          {:err, reason} ->
            IO.puts("Can't send an invitation. Try again later.")
            Logger.error("Tried to invite user #{player}, got error: #{reason}")
            invite_until_back(options)
        end
    end
  end
end
