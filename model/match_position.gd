class_name MatchPosition
extends RefCounted

## Everything on the table at one moment of a match, without the true rules:
## board, first player, turn, current colour, skip counts and history.
## Rules are checked against a position, and a match can start from one.

var board: Board
## The player who took (or takes) the first turn; rows are numbered from their side.
var first_player: int
## 0 before the first colour pick; turn n starts with the n-th colour pick.
## Odd turns belong to the first player, even turns (and turn 0) to the other.
var turn: int = 0
## The colour the current player places; "" before the first colour pick.
var colour: String = ""
## Skip count per player.
var skips: Array[int] = [0, 0]
var history: Array[HistoryEntry] = []


## A position at turn 0 with no history: on its own, a board for checking rules.
func _init(p_board: Board = Board.new(), p_first_player: int = 0) -> void:
	board = p_board
	first_player = p_first_player


## The player whose turn it is; at turn 0, the player who picks the first colour.
func current_player() -> int:
	return first_player if turn % 2 == 1 else Players.opponent(first_player)


## The player's most recent placement, or null before their first one. Other
## events (colour picks, skips) never change it.
func last_placement(player: int) -> HistoryEntry:
	for i: int in range(history.size() - 1, -1, -1):
		var entry: HistoryEntry = history[i]
		if entry.type == HistoryEntry.Type.PLACEMENT and entry.player == player:
			return entry
	return null


## The position just before the placement or skip at history[index]: every
## later placement taken off the board, later colour picks and skips undone,
## history cut before it. Its colour is the event's colour. Works even when
## the match started from a position whose board its history didn't build.
func before(index: int) -> MatchPosition:
	var later_cells: Array[Vector2i] = []
	var later_picks: int = 0
	var later_skips: Array[int] = [0, 0]
	for i: int in range(index, history.size()):
		var event: HistoryEntry = history[i]
		match event.type:
			HistoryEntry.Type.PLACEMENT:
				later_cells.append(event.cell)
			HistoryEntry.Type.COLOUR_PICK:
				later_picks += 1
			HistoryEntry.Type.SKIP:
				later_skips[event.player] += 1
	var earlier_board: Board = Board.new()
	for cell: Vector2i in Board.all_cells():
		var ball: Ball = board.ball_at(cell)
		if ball != null and not later_cells.has(cell):
			earlier_board.place(cell, ball)
	var earlier: MatchPosition = MatchPosition.new(earlier_board, first_player)
	earlier.turn = turn - later_picks
	earlier.colour = history[index].colour
	for player: int in Players.COUNT:
		earlier.skips[player] = skips[player] - later_skips[player]
	earlier.history = history.slice(0, index)
	return earlier


## A deep copy that shares no mutable state with this position.
func copy() -> MatchPosition:
	var position: MatchPosition = MatchPosition.new(board.copy(), first_player)
	position.turn = turn
	position.colour = colour
	position.skips = skips.duplicate()
	for entry: HistoryEntry in history:
		position.history.append(entry.copy())
	return position
