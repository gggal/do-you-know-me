defmodule Screen do
  @moduledoc """
  This module represents a form/screen shown to the user.
  """

  @doc """
  Shows the screen message, reads user input, connects to the server and performs
  actual logic.
  Returns the run function of the next form to be displayed.
  """
  @callback run(any()) :: {:ok, fun()} | :exit | {:err, String.t()}
  @callback run() :: {:ok, fun()}
  @optional_callbacks run: 0, run: 1
end
