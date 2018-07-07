defmodule Server.Application do
  @moduledoc """
  Server Application

  """

  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    # case Server.Connectivity.questions_file_accessible?() do
    #  true ->
    case Server.Connectivity.try_make_accessible() do
      {:ok, _} ->
        children = [
          worker(Server.Worker, [])
        ]

        opts = [strategy: :one_for_one, name: Server.Supervisor]
        Supervisor.start_link(children, opts)

      anything ->
        {:error, anything}
    end

    #   false ->
    #     {:error, "Questions file couldn't be open or doesn't exist."}
    # end
  end
end
