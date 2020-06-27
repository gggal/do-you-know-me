defmodule StateMachine do
  use GenServer

  @states %{
    intro: %{login: :login, register: :register, exit: :exit},
    login: %{succ: :main_menu},
    register: %{succ: :main_menu},
    main_menu: %{
      invite: :all_users,
      get_scores: :scores,
      get_invites: :invitation_menu,
      play: :game_menu,
      exit: :exit
    },
    all_users: %{back: :main_menu},
    scores: %{back: :main_menu},
    invitation_menu: %{choose: :invitation, back: :main_menu},
    invitation: %{back: :invitation_menu, play: :game},
    game_menu: %{choose: :game, back: :main_menu},
    game: %{back: :game_menu, play: :game},
    exit: %{}
  }

  # __________API__________#

  def start() do
    GenServer.start_link(__MODULE__, nil, name: :state_machine)
  end

  def move(move) do
    GenServer.call(:state_machine, {:move, move})
  end

  def get_state() do
    GenServer.call(:state_machine, :get_state)
  end

  # __________Callbacks__________#

  @impl true
  def init(_) do
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
      nil -> {:reply, :err, state}
    end
  end
end
