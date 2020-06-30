defmodule CLI.Application do
  @moduledoc """
  The Application module that starts and manages all processes for the CLI
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
      },
      %{
        id: NotifierSupervisor,
        start: {CLI.NotifierSupervisor, :start_link, []}
      },
      %{
        id: CLIWorker,
        start: {CLI, :start_link, []}
      }
    ]

    # All workers should be restarted if one of them fails
    {:ok, _pid} = Supervisor.start_link(children, strategy: :one_for_all)
  end
end
