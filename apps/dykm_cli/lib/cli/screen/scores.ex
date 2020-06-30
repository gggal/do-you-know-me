defmodule CLI.Scores do
  @behaviour CLI.Screen
  @moduledoc """
  The scores screen shows the current scores for all games the player is in,
  in a tabular format.
  """
  require Logger

  alias Client.Worker, as: Client

  @doc """
  Prints the scores table and the summary.
  """
  @impl CLI.Screen
  def run() do
    with {:ok, users} <- Client.list_related() do
      users
      |> Enum.map(fn line -> get_scores(line) end)
      |> Enum.filter(fn line -> not is_nil(line) end)
      |> Scribe.print(data: ["user", "other's success", "your success"])

      print_summary(users)
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

  defp print_summary(users) do
    with first when not is_nil(first) <- other_to_best_know_user(users),
         sec when not is_nil(sec) <- best_known_other(users) do
      IO.puts("\nThe user who knows you best is: #{first}")
      IO.puts("The user you know best is: #{sec}\n")
    end
  end

  defp best_known_other(users) do
    Enum.max_by(users, fn user -> get_curr_user_score(user) end, &>=/2, fn -> nil end)
  end

  defp other_to_best_know_user(users) do
    Enum.max_by(users, fn user -> get_other_score(user) end, &>=/2, fn -> nil end)
  end

  defp get_curr_user_score(user) do
    {:ok, score1, _} = Client.get_score(user)
    score1
  end

  defp get_other_score(user) do
    {:ok, _, score2} = Client.get_score(user)
    score2
  end
end
