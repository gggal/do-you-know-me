defmodule StateMachineTest do
  use ExUnit.Case

  setup_all do
    {:ok, _pid} = StateMachine.start()
    :ok
  end

  setup do
    :sys.replace_state(:state_machine, fn _ -> :intro end)
    :ok
  end

  test "getting the correct initial state after initialization" do
    assert :intro == StateMachine.get_state()
  end

  test "getting the current state after move" do
    StateMachine.move(:login)
    assert :login == StateMachine.get_state()
  end

  test "try moving the state when there's no such transition" do
    assert :err == StateMachine.move(:no_such_state)
  end

  test "moving the state successfully" do
    assert {:ok, :login} == StateMachine.move(:login)
  end
end
