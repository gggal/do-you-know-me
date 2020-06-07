defmodule Notifier do
  use GenServer

  def start_link(username) do
    GenServer.start_link(__MODULE__, username, name: :notifier)
  end

  @doc """

  """
  def init(username) do
    {:ok,
     %{
       user: username,
       invitations: GenServer.call(:quiz_client, :see_invitations),
       best_score: nil,
       waiting: %{}
     }}
  end

  @doc """
  """
  def handle_call(:notify_invitations, _from, %{invitations: players} = state) do
    current = current_invitations()

    {:reply, MapSet.difference(current, players),
     %{state | invitations: MapSet.union(current, players)}}
  end

  def handle_call(:notify_best, _from, state) do
  end

  def handle_call(:notify_waiting, _from, state) do
  end

  defp current_invitations() do
    GenServer.call(:quiz_client, :see_invitations)
    |> Enum.map(fn {key, _val} -> key end)
    |> MapSet.new()
  end
end
