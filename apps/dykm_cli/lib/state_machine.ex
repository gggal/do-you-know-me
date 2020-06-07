defmodule StateMachine do
  use GenServer

  @states %{
    intro: %{login: :login, register: :register, exit: :end_game},
    login: %{succ: :main_menu},
    register: %{succ: :main_menu},
    main_menu: %{
      invite: :all_users,
      get_scores: :scores,
      get_invites: :inv_menu,
      play: :game_menu
    },
    all_users: %{back: :main_menu},
    scores: %{back: :main_menu},
    inv_menu: %{choose: :invitation, back: :main_menu},
    invitation: %{back: :inv_menu},
    game_menu: %{choose: :game, back: :main_menu},
    game: %{back: :game_menu}
  }

  # __________API__________#

  def start() do
    GenServer.start_link(__MODULE__, name: :state_machine)
  end

  def move(move) do
    GenServer.call(:state_machine, {:move, move})
  end

  def get_state() do
    GenServer.call(:state_machine, :get_state)
  end

  # __________Callbacks__________#

  @impl true
  def init() do
    # intro is the start state
    {:ok, :intro}
  end

  @impl true
  def handle_call(:get_state, _from, state), do: {:reply, state, state}

  def handle_call({:move, transition}, _from, state) do
    with new_state when not is_nil(new_state) <-
           @states
           |> Map.get(state)
           |> Map.get(transition) do
      {:reply, {:ok, new_state}, new_state}
    else
      nil -> {:reply, :err, new_state}
    end
  end
end
