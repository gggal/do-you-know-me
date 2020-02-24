defmodule Screen do
  @moduledoc """
  This module represents a form/screen shown to the user.
  """

  @typedoc """
  Type of validated user input.
  """
  @type input :: String.t() | Int.t()

  @type specific :: nil | String.t()

  @doc """
  Introduces the screen to the user. Provides them with information on what to do
  in order to procede with the game.
  """
  @callback show() :: :ok
  @callback show(specific) :: :ok
  @optional_callbacks show: 0, show: 1

  @doc """
  Reads and validates user's input with respect to the previously showed message.
  Returns users input or accurate error message.
  """
  @callback prompt_and_read_input(specific) :: {:ok, input} | {:err, String.t()}

  @callback prompt_and_read_input() :: {:ok, input} | {:err, String.t()}
  @optional_callbacks prompt_and_read_input: 0, prompt_and_read_input: 1

  @doc """
  Shows the screen message, reads user input, connects to the server and performs
  actual logic.
  Returns the run function of the next form to be displayed.
  """
  @callback run(specific) :: fun()
  @callback run() :: fun()
  @optional_callbacks run: 0, run: 1

  @doc """
  Returns the run function of the next form to be displayed.
  """
  @callback transition(input | nil) :: {:ok, fun()} | {:err, String.t()}
end
