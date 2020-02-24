defmodule OnlineUsers do
  require Logger
  @behaviour Screen
  @moduledoc """
  This screen shows all online users and gives the user the chance to
  send invitations.
  """

  @doc """
  Shows all available users to send invitations to, enumerated.
  """
  @impl Screen
  def show() do
    IO.puts("Players:\n\n")

    Client.Application.list_registered()
    |> Enum.concat(["back"])
    |> Enum.with_index(1)
    |> Enum.map(fn {user, idx} -> "#{idx}. #{user}\n" end)
    |> Enum.join()
    |> IO.puts()
  end

  @doc """
  Makes user choose a user to invite to a game by choosing their number
  """
  # TODO list users you're not playing it (diff with list_related)
  @impl Screen
  def prompt_and_read_input() do
    user_input = CLI.read_format_int("Choose a number to send invitation to: \n")
    to = Client.Application.list_registered() |> Enum.count()

    case Client.Application.list_registered()
         |> Enum.concat(["back"])
         |> CLI.read_input_menu(user_input) do
      nil -> {:err, "Choose a number between 1 and #{to + 1}."}
      res -> {:ok, res}
    end
  end

  @doc """
  Shows available users, sends invitations.
  """
  @impl Screen
  def run() do
    show()
    invite_until_back()
    transition(:dummy)
  end

  @doc """
  Sends invitations until user decides to go back to main menu
  """
  def invite_until_back() do
    case CLI.loop_until_correct_input(&prompt_and_read_input/0) do
      "back" ->
        :ok

      player ->
        Client.Application.invite(player)
        IO.puts("An invitation was sent...\n")
        invite_until_back()
    end
  end

  @doc """
  Goes back to main menu.
  """
  @impl Screen
  def transition(_user_input) do
    {:ok, &MainMenu.run/0}
  end
end
