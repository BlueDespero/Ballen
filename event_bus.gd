extends Node

signal dragsignal
## A match started: the coin toss (or a rematch's turn order) is over. ai_level is
## the AI level's title in lower case (e.g. "hard").
signal match_started(player_goes_first: bool, ai_level: String)
## A ball landed on the board in the match scene.
signal ball_placed(by_player: bool, cell: Vector2i)
## A colour was picked for the other player's next ball in the match scene.
signal colour_picked(by_player: bool, colour: String)
## The deck editor saved a deck under this name.
signal deck_saved(deck_name: String)
## The Decks screen listed these decks, Starter first.
signal decks_listed(deck_names: Array[String])
## The player pressed Start with this secret rule, seconds after the setup
## screen opened; picked_for_me when Pick for me chose it.
signal secret_rule_picked(rule_id: String, seconds: float, picked_for_me: bool)
## A guess was made on this turn (forced guesses too, as the match ends).
signal guessed(by_player: bool, turn: int, right: bool)
## The player pressed Guess (or Seal) before selecting one of the AI's rules.
signal guess_blocked
