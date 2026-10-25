class_name PublicView
extends RefCounted

## Everything one player may know about a match (ADR 0002): a snapshot built
## by Match.public_view(viewer), holding no reference back to the match. It
## never holds the opponent's true rule or the opponent's legal cells.
## Changing a view changes nothing in the match.

## The player this view was built for.
var viewer: int
var phase: Match.Phase
## The player whose turn it is (during FIRST_COLOUR, the player picking it).
var current_player: int
## Board, first player, turn, current colour, skip counts and history.
var position: MatchPosition
## Both players' decks, indexed by player.
var decks: Array[Deck] = []
## The viewer's own true rule.
var own_true_rule: Rule
## Null while the match runs.
var result: MatchResult


func opponent() -> int:
	return Players.opponent(viewer)


## The viewer's legal cells for the current colour when it is their turn to
## place; empty otherwise. Computed from the viewer's own true rule only.
func own_legal_cells() -> Array[Vector2i]:
	if phase != Match.Phase.PLACE or current_player != viewer:
		return []
	return RuleChecker.legal_cells(own_true_rule, position, viewer, position.colour)
