# DYKM Engine
The DYKM engine is the back-end service for the game. It contains a list of components that work together:
  - Postgres database - the db for the game; it's accessible by a set of ORM modules that comunicate with the underlying database
  - DYKM server - acts as a single-point-of-contact with the database, persists data in the database, keeps track of clients, users and the relationships between them
  - DYKM client - represents a client in the game by providing an API to the engine; keeps user related data in its internal state
------
## Start the game server
  - clone the repo
  - prepare the database - Assuming you have PosgreSQL already set up on the host, all you need to do is run "mix ecto.migrate" in the engine main directory. 
  - make sure the epmd daemon is up by running "epmd -daemon"
  - start the server - Go to the main "engine" directory and run the start_server script, located in the main directory of the engine project. In order to make the server accessible in your local network, set the DYKM_SERVER_LOCATION env variable that's being exported in the script to your local IP address.
------
## Add a UI
When implementing a UI for the game, the following steps should be taken:
  - add `engine` to the list of dependencies in `mix.exs`
 ```elixir
def deps do
  [
    {:engine, runtime: false}
  ]
end
```
  - configure environment variables

    - DYKM_SERVER_NAME, DYKM_SERVER_LOCATION and DYKM_SERVER_COOKIE - It is important to note that the **Server** process needs to be running and to be accessible in order to start a **Client** process. If that is not the case, a failed_to_connect_to_server_node error will be received. You need to know the server name, location and cookie in order to connect to it. By default their values are "server", "127.0.0.1" and "dykm_elixir_cookie" respectively but they can be set to any value, especially in a distributed environment. For the client to be able to connect to the server, these three values must be correctly set. That's done by exporting the DYKM_SERVER_NAME, DYKM_SERVER_LOCATION and DYKM_SERVER_COOKIE environment variables.
    - DYKM_CLIENT_NAME - The name of the node for the client. If not set, a random number will be user as a name.
    - DYKM_CLIENT_LOCATION - The IP address for the client. If not set, its value will be "127.0.0.1".
  - start the **Client** process as a part of the new project
 ```elixir
 Client.Worker.start_link()
 ```
------
## Test the engine
There are unit and integration tests available, located in test/unit and test/integration respectively. Each of these types are to be executed in their own environment which is "test" for unit tests and "integration" for integration test. There are a few aliases that can be used to run tests easily:
  - mix test.unit - to run unit tests
  - mix test.integration - to run integration tests
  - mix test.all - to run both, each in its own environment
Note: make sure to unset all environment variables from above
