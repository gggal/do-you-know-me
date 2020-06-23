defmodule CLI.Scores do
  @behaviour Screen
  @moduledoc """
  The scores screen shows the current scores for all games.
  """
  require Logger

  alias Client.Worker, as: Client

  @doc """
  Prints the scores and goes back to the previous screen.
  """
  @impl Screen
  def run() do
    with {:ok, users} <- Client.list_related() do
      users
      |> Enum.map(fn line -> get_scores(line) end)
      |> Enum.filter(fn line -> not is_nil(line) end)
      |> Scribe.print(data: ["user", "other's success", "your success"])
    else
      {:err, reason} ->
        Logger.error("Listing users failed: #{reason}")
        IO.puts("Something went wrong. Try again later...\n")
    end

    IO.gets("Press enter to continue...")
    {:back, []}
  end

  defp get_scores(user) do
    with {:ok, score1, score2} <- Client.get_score(user) do
      %{"user" => user, "your success" => score1, "other's success" => score2}
    else
      {:err, reason} ->
        Logger.error("Getting scores with #{user} failed: #{reason}")
        nil
    end
  end
end
