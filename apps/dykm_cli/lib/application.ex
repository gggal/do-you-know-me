defmodule CLI.Application do
  @moduledoc """
  Single point of access between the user interfaces and the client.
  """

  require Logger

  use Application


  @doc """
  Starting the client application
  """
  def start(_, _) do
    children = [
      %{
        id: ClientWorker,
        start: {Client.Worker, :start_link, []}
      },
      %{
        id: StateMachineWorker,
        start: {StateMachine, :start, []}
      }
    ]

    # All workers should be restarted if one of them fails
    {:ok, _pid} = Supervisor.start_link(children, strategy: :one_for_all)
  end

  # TODO: add functionality for listing only users eligable for inviting
end
