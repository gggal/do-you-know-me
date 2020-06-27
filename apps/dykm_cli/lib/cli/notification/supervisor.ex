defmodule CLI.NotifierSupervisor do
  use Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {CLI.InvitationNotifier, [1]}
    ]

    # if a notifier fails, restart only it
    Supervisor.init(children, strategy: :one_for_one)
  end
end
