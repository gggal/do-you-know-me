export DYKM_SERVER_NAME="hello"
export DYKM_SERVER_LOCATION="192.168.0.197"

MIX_ENV=prod iex -S mix
#MIX_ENV=prod elixir --name app@hostname --cookie "MyErlangCookie" -S mix run --no-compile --no-halt