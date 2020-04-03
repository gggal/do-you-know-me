defmodule Server.ScoreTest do
  use ExUnit.Case

  alias Server.Score

  # TODO think about reusing this module
  defmodule ScoreState do
    use Agent

    def start_link, do: Agent.start_link(fn -> :ok end, name: __MODULE__)
    def get_id, do: Agent.get(__MODULE__, & &1)
    def set_id(id), do: Agent.update(__MODULE__, fn _ -> id end)
  end

  setup_all do
    {:ok, %{id: id}} =
      %Score{hits: 0, misses: 0}
      |> DB.Repo.insert()

    ScoreState.start_link()
    ScoreState.set_id(id)
    on_exit(fn -> %Score{id: id} |> DB.Repo.delete() end)
  end

  test "get hits for non-existent score" do
    assert :err == Score.get_hits(-1)
  end

  test "get hits for nil score" do
    assert :err == Score.get_hits(nil)
  end

  test "get hits for existent score" do
    assert :ok == Score.get_hits(ScoreState.get_id()) |> elem(0)
  end

  test "get misses for non-existent score" do
    assert :err == Score.get_misses(-1)
  end

  test "get misses for nil score" do
    assert :err == Score.get_misses(nil)
  end

  test "get misses for existent score" do
    assert :ok == Score.get_misses(ScoreState.get_id()) |> elem(0)
  end

  test "set hits to nil" do
    assert false == Score.set_hits(ScoreState.get_id(), nil)
  end

  test "set hits to -1" do
    assert false == Score.set_hits(ScoreState.get_id(), -1)
  end

  test "set hits to a valid value" do
    assert true == Score.set_hits(ScoreState.get_id(), 1)
  end

  test "set hits to non-existent score" do
    assert false == Score.set_hits(-1, 1)
  end

  test "set hits for score with nil id" do
    assert false == Score.set_hits(nil, 1)
  end

  test "set misses to nil" do
    assert false == Score.set_misses(ScoreState.get_id(), nil)
  end

  test "set misses to -1" do
    assert false == Score.set_misses(ScoreState.get_id(), -1)
  end

  test "set misses to a valid value" do
    assert true == Score.set_misses(ScoreState.get_id(), 1)
  end

  test "set misses to non-existent score" do
    assert false == Score.set_misses(-1, 1)
  end

  test "set misses for score with nil id" do
    assert false == Score.set_misses(nil, 1)
  end
end
