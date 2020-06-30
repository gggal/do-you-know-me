# DYKM Game
DYKM Game is a game played by two users who answer and guess personal questions in order to see how good they know their friends and how good their friends knows them. Each question consists of the question itself and a/b/c options for the user to choose from. There are generally three types of questions which users consecutively receive:
  - 'Answer' question - a question that the user has to answer for themselves
  - 'Guess' question - a question for which the user has to guess their co-player's answer
  - 'See' questions - the point of this question is to inform the user of what the other player has guessed and if this guess was successful or not

Players can play with any other player. To do that, they need to send an invite. The other player can either decline or accept it. In case of the latter, the game starts.
There are no winners or losers. Instead, success rate percentages are calculated for every couple of players who are in a game.
------
# About this repo
This repository contains 2 projects:
  - engine - the backend service
  - CLI - UI for the game, uses the engine as a dependency
------
# Next TODOs

1. Add password hashing
2. Phoenix - GUI

add license
fix nasty bug
deployment + connectivity tests