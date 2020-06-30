defmodule Server.Connectivity do
  def try_make_accessible do
    case Node.alive?() do
      true ->
        {:ok, true}

      false ->
        name = System.get_env("DYKM_SERVER_NAME") || "server"
        location = System.get_env("DYKM_SERVER_LOCATION") || "127.0.0.1"
        cookie = System.get_env("DYKM_SERVER_COOKIE") || "dykm_elixir_cookie"

        node = Node.start(:"#{name}@#{location}")
        Node.set_cookie(Node.self(), :"#{cookie}")

        node
    end
  end
end
