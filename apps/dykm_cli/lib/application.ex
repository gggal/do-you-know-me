defmodule CLI.Application do
  @moduledoc """
  Single point of access between the user interfaces and the client.
  """

  require Logger

  use Application

  def main(args) do
    options = [switches: [file: :string], aliases: [f: :file]]
    {opts, _, _} = OptionParser.parse(args, options)
    IO.inspect(opts, label: "Command Line Arguments")
    # CLI.start_game()
  end

  @doc """
  Starting the client application
  """
  def start(_, _) do
    import Supervisor.Spec, warn: false

    # with nick when not is_nil(nick) <- Client.Connectivity.nick(),
    #      true <- Client.Connectivity.connect_to_server_node("127.0.0.1") do
    # with nick when not is_nil(nick) <- Client.Connectivity.nick() do
    children = [
      # Starts a worker by calling: Client.Worker.start_link(arg)
      worker(Client.Worker, [])
    ]

    opts = [strategy: :one_for_one, name: Client.Supervisor]
    Supervisor.start_link(children, opts)
    # else
    # _ -> {:error, "Can't connect to server or establish client."}
    # end
  end

  # TODO: add functionality for listing only users eligable for inviting
  # TODO: cant reinvite after the first invitation got declined
end
