# DYKM Command Line Interface
This application is a UI for the DYKM game.

------
# Definitions
- Screen - an interactive unit that serves a particular purpose, e.g. the MainMenu screen shows all generic options that the game has to offer and promts the user to choose one
- Related users - a couple of users for which there's a game record in the databae
- Notification - text printed on top of a screen; as of now only "new invitation" notification is supported 
------
# Workflow

The navigation through the game is implemented via a finite state machine. The supported functionality uncludes:
  - creating a profile
  - logging in a profile
  - sending and accepting/declining invitations
  - obtaining scores and ranking for users
  - playing the game
    
In order to access the full functionality, the user needs to authenticate first, meaning they have to choose from 2 options: login (when the user already has an acount for the game) and register (when the user wants to create a new acount). For two users to play the game, they first have to mutually agree to that - either by inviting each other or one inviting the other and the other accepting the invite. Once they do that, each will take turn to answer, guess and inspect questions. When it's the current player's turn to play, they will see a '*' sign succeeding the other player's name in the Play screen.

------
## Start the CLI
Run the './start_cli' command in the main directory of the project. 

------
## Recompile the CLI
Run 'mix escript.build' which will update the cli file.


