defmodule Server.TestClient do
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, nil, name: :quiz_client)
  end

  def init(_) do
    {:ok, nil}
  end

  def handle_call(:set_tester, {pid, _}, _) do
    {:reply, :ok, pid}
  end

  def handle_call(args, _, tester) do
    send(tester, {node(), :call, args})
    {:reply, :ok, tester}
  end

  def handle_cast(args, tester) do
    send(tester, {node(), :cast, args})
    {:noreply, tester}
  end
end
