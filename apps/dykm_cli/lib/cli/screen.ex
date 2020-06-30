defmodule CLI.Screen do
  @moduledoc """
  This module represents a form/screen shown to the user.
  """

  @doc """
  Shows the screen message, reads user input, connects to the server and performs
  some action.
  Returns the next move to be performed on the state machine depending on the result
  of the performed action + additional arguments for the next screen.
  """
  @callback run(any()) :: {:ok, fun()} | :exit | {:err, String.t()}
  @callback run() :: {:ok, fun()}
  @optional_callbacks run: 0, run: 1
end
