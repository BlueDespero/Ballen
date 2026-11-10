class_name PlacementContext
extends RefCounted

## What a rule may look at when it judges one placement. Built by RuleChecker;
## parts read it and never change it.

## The board as it would be after the placement (the target holds the new ball).
var board: Board
var target: Vector2i
## The colour of the ball being placed.
var colour: String
## The player whose deck holds the rule ("you" in rule text).
var holder: int
## The position before the placement: first player, and whatever later tickets
## add for rules to read (history, turn number, skip counts).
var position: MatchPosition
## Values that are the same for every target of one placement check (see
## Parts.mark_invariant); RuleChecker.legal_cells shares one across its cells.
var cache: Dictionary = {}


## p_board, if given, is the board after the placement (it already holds the
## new ball on the target), so a caller trying many cells can reuse one board;
## otherwise a copy of the position's board with the new ball is made.
## p_cache, if given, is shared by every context of one placement check.
func _init(p_position: MatchPosition, p_holder: int, p_colour: String, p_target: Vector2i, p_board: Board = null,
		p_cache: Variant = null) -> void:
	position = p_position
	if p_cache != null:
		cache = p_cache
	holder = p_holder
	colour = p_colour
	target = p_target
	board = p_board if p_board != null else p_position.board.with_ball(p_target, Ball.new(p_colour, p_holder))


## The cell of the player's last ball (their most recent placement before this
## one) as a list of one cell; empty before their first placement.
func last_ball(player: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var entry: HistoryEntry = position.last_placement(player)
	if entry != null:
		cells.append(entry.cell)
	return cells


## The holder's own turn count: how many of the match's turns so far are the
## holder's, this one included (1 on their first turn). Odd match turns belong
## to the first player, even ones to the other player; a skipped turn counts.
func own_turn() -> int:
	return own_turn_of(position, holder)


## The player's own turn count in this position (see own_turn).
@warning_ignore("integer_division")
static func own_turn_of(p_position: MatchPosition, player: int) -> int:
	if player == p_position.first_player:
		return (p_position.turn + 1) / 2
	return p_position.turn / 2
