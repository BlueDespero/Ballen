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


func _init(p_board: Board = Board.new(), p_first_player: int = 0) -> void:
	board = p_board
	first_player = p_first_player


## A position holding only a board, for checking rules.
static func from_board(p_board: Board, p_first_player: int = 0) -> MatchPosition:
	return MatchPosition.new(p_board, p_first_player)


## The player whose turn it is; at turn 0, the player who picks the first colour.
func current_player() -> int:
	return first_player if turn % 2 == 1 else Players.opponent(first_player)


## The player's most recent placement, or null before their first one. Other
## events (colour picks, and skips once they exist) never change it.
func last_placement(player: int) -> HistoryEntry:
	for i: int in range(history.size() - 1, -1, -1):
		var entry: HistoryEntry = history[i]
		if entry.type == HistoryEntry.Type.PLACEMENT and entry.player == player:
			return entry
	return null


## A deep copy that shares no mutable state with this position.
func copy() -> MatchPosition:
	var position: MatchPosition = MatchPosition.new(board.copy(), first_player)
	position.turn = turn
	position.colour = colour
	position.skips = skips.duplicate()
	for entry: HistoryEntry in history:
		position.history.append(entry.copy())
	return position
