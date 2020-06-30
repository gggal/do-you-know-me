export DYKM_SERVER_NAME="dykm_server"
export DYKM_SERVER_LOCATION="192.168.0.197"
export DYKM_SERVER_COOKIE="dykm_elixir_cookie"

MIX_ENV=prod iex --cookie "dykm_elixir_cookie" -S mix
#MIX_ENV=prod elixir --name app@hostname --cookie "MyErlangCookie" -S mix run --no-compile --no-halt