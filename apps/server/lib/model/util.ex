defmodule Server.Util do
  require Logger

  def changeset_to_bool(changeset) do
    case changeset do
      {:ok, _} ->
        true

      {:error, changeset} ->
        Logger.error(
          "Couldn't perform action #{inspect(changeset.action)} in the database, reason: #{
            inspect(changeset.errors)
          }"
        )

        false
    end
  end
end
