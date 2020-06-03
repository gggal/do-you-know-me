defmodule Server.ConnectivityTest do
  use ExUnit.Case

  test "starting server" do
    {:ok, pid} = Server.Worker.start_link()
    assert Process.alive?(pid)
    # assert Process.alive?(:global.whereis_name("server"))
  end
end
