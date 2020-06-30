export DYKM_SERVER_NAME="dykm_server"
export DYKM_SERVER_LOCATION="192.168.0.197"
export DYKM_SERVER_COOKIE="dykm_elixir_cookie"

MIX_ENV=prod elixir --cookie $DYKM_SERVER_COOKIE -S mix run --no-compile --no-halt