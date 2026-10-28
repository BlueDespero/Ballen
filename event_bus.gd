extends Node

signal dragsignal
## A match started: the coin toss (or a rematch's turn order) is over.
signal match_started(player_goes_first: bool)
## A ball landed on the board in the match scene.
signal ball_placed(by_player: bool, cell: Vector2i)
## The deck editor saved a deck under this name.
signal deck_saved(deck_name: String)
## The Decks screen listed these decks, Starter first.
signal decks_listed(deck_names: Array[String])
