defmodule CLI.InvitationNotifier do
  use GenServer
  alias Client.Worker, as: Client

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: :invite_notifier)
  end

  def init(_) do
    schedule_wait()
    {:ok, nil}
  end

  def handle_info(:wait, _state) do
    # waiting until the client has a user logged in through it
    with name when not is_nil(name) <- Client.username() do
      schedule_poll()
      {:ok, all_invites} = Client.get_invitations()
      {:noreply, MapSet.new(all_invites)}
    else
      nil ->
        schedule_wait()
        {:noreply, nil}
    end
  end

  def handle_info(:poll, prev_invites) do
    {:ok, curr_invites} = Client.get_invitations()
    curr_invites_set = MapSet.new(curr_invites)
    # notify the cli worker for every new invitation
    curr_invites_set
    |> MapSet.difference(prev_invites)
    |> Enum.map(fn player -> CLI.notify_invite(player) end)

    schedule_poll()

    {:noreply, curr_invites_set}
  end

  def schedule_poll, do: Process.send_after(self(), :poll, 1_000)

  def schedule_wait, do: Process.send_after(self(), :wait, 5_000)
end
