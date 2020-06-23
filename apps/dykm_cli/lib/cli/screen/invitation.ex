defmodule CLI.Invitation do
  @behaviour Screen
  @moduledoc """
  This module represents an open invitation. The user has a choice:
  they can accept or reject the invitation.
  """

  alias Client.Worker, as: Client

  require Logger

  @doc """
  Removes the invitation by accepting or declining it. Regardless of
  the choice, it goes back to invitations screen.
  """
  @impl Screen
  def run(other_user) do
    IO.puts("Accept/decline this invitation:")

    user_input =
      [:accept, :decline, :back]
      |> CLI.Util.print_menu()
      |> CLI.Util.choose_menu_option()

    case user_input do
      :accept ->
        with {:err, reason} <- Client.accept(other_user) do
          Logger.error("Accepting invitation failed: #{reason}")
          IO.puts("Something went wrong and the invitation was not accepted.
          Try again later...\n")
        end

      :decline ->
        with {:err, reason} <- Client.decline(other_user) do
          Logger.error("Declining invitation failed: #{reason}")
          IO.puts("Something went wrong and the invitation was not declined.
          Try again later...\n")
        end

      :back ->
        true
    end

    {:back, []}
  end
end
