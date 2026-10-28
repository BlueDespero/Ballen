class_name PublicView
extends RefCounted

## Everything one player may know about a match (ADR 0002): a snapshot built
## by Match.public_view(viewer), holding no reference back to the match. It
## never holds the opponent's legal cells, nor the opponent's true rule while
## the match runs. Changing a view changes nothing in the match.

## The player this view was built for.
var viewer: int
var phase: Match.Phase
## The player whose turn it is (during FIRST_COLOUR, the player picking it).
var current_player: int
## The players the match is waiting for a command from.
var awaiting_players: Array[int] = []
## Board, first player, turn, current colour, skip counts and history.
var position: MatchPosition
## Both players' decks, indexed by player.
var decks: Array[Deck] = []
## The viewer's own true rule.
var own_true_rule: Rule
## Null while the match runs.
var result: MatchResult
## Both players' true rules, indexed by player, once the match is over; empty
## while it runs.
var revealed_true_rules: Array[Rule] = []


func opponent() -> int:
	return Players.opponent(viewer)


## Whether one of the viewer's guess windows is open: their turn, before
## placing or after placing or skipping, until they pick a colour; after
## filling the board, until their forced guess.
func can_guess() -> bool:
	if current_player != viewer:
		return false
	if phase == Match.Phase.FORCED_GUESS:
		return forced_guess_due()
	return phase == Match.Phase.PLACE or phase == Match.Phase.PICK_COLOUR


## Whether the board is full and the match is waiting for the viewer's forced
## guess.
func forced_guess_due() -> bool:
	return phase == Match.Phase.FORCED_GUESS and awaiting_players.has(viewer)


## The viewer's legal cells for the current colour when it is their turn to
## place; empty otherwise. Computed from the viewer's own true rule only.
func own_legal_cells() -> Array[Vector2i]:
	if phase != Match.Phase.PLACE or current_player != viewer:
		return []
	return RuleChecker.legal_cells(own_true_rule, position, viewer, position.colour)
