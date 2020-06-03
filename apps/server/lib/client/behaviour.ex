defmodule Client.Behaviour do
  @type client() :: __MODULE__

  @callback cast_invitation(client(), String.t()) :: :ok
  @callback cast_to_answer(client(), String.t(), integer()) :: :ok
  @callback cast_to_guess(client(), String.t(), integer(), String.t()) :: :ok
  @callback cast_to_see(client(), String.t(), integer(), String.t(), String.t()) :: :ok
end
