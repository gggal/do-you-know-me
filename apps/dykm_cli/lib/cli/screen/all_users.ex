defmodule CLI.AllUsers do
  require Logger
  @behaviour CLI.Screen
  @moduledoc """
  This screen shows all players that can be invited and gives the player the chance to
  do so by choosing a number.
  """

  alias Client.Worker, as: Client

  @doc """
  Shows available players and sends invitations.
  """
  @impl CLI.Screen
  def run() do
    IO.puts("Other players:\n\n")

    with {:ok, all_list} <- Client.list_registered(),
         {:ok, related_list} <- Client.list_related() do
      # all players in the game excluding those that are already invited/playing
      MapSet.new(all_list)
      |> MapSet.difference(MapSet.new(related_list))
      |> MapSet.to_list()
      |> Enum.concat(["back"])
      |> CLI.Util.print_menu()
      |> invite_until_back()
    else
      {:err, reason} ->
        Logger.error("Listing users failed: #{reason}")
        IO.puts("An error occurred while communicating with the engine.
        Try again later.")
        {:back, []}
    end
  end

  # Sends invitations until user decides to go back to main menu
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
