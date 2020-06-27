defmodule CLI.State do
  alias __MODULE__

  @type t :: %State{}

  @enforce_keys [:invites]
  defstruct [:invites]

  def new(), do: %State{invites: MapSet.new()}

  def add_invite(state = %State{invites: all}, player) when is_binary(player) do
    %{state | invites: MapSet.put(all, player)}
  end

  def get_invites(%State{invites: players}), do: MapSet.to_list(players)

  def delete_invites(%State{} = state), do: %{state | invites: MapSet.new()}
end
