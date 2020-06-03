defmodule Server.Application do
  @moduledoc """
  Server Application

  """
  # TODO rename to engine
  use Application
  require Logger

  def start(_type, _args) do
    import Supervisor.Spec

    case Server.Connectivity.try_make_accessible() do
      {:ok, _} ->
        children = [
          worker(Server.Worker, []),
          supervisor(DB.Repo, [])
        ]

        Logger.info("Starting server...")
        opts = [strategy: :one_for_one, name: Server.Supervisor]
        Supervisor.start_link(children, opts)

      anything ->
        {:error, anything}
    end
  end
end
