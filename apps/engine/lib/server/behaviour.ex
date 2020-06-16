defmodule Server.Behaviour do
  @callback register(String.t(), String.t()) :: atom()
  @callback login(String.t(), String.t()) :: atom()
  @callback unregister(String.t()) :: atom()
  @callback list_users() :: atom() | {:ok, list()}
  @callback invite(String.t()) :: atom()
  @callback accept(String.t()) :: atom()
  @callback decline(String.t()) :: atom()
  @callback answer_question(String.t(), String.t()) :: atom()
  @callback guess_question(String.t(), String.t()) :: atom()
  @callback get_score(String.t()) :: atom() | {:ok, float(), float()}
  @callback get_turn(String.t()) :: atom() | {:ok, boolean()}
end
