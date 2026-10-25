class_name MatchPosition
extends RefCounted

## Everything on the table at one moment of a match, without the true rules.
## Rules are checked against a position, and a match can start from one.

var board: Board
## The player who took (or takes) the first turn; rows are numbered from their side.
var first_player: int


func _init(p_board: Board = Board.new(), p_first_player: int = 0) -> void:
	board = p_board
	first_player = p_first_player


## A position holding only a board, for checking rules.
static func from_board(p_board: Board, p_first_player: int = 0) -> MatchPosition:
	return MatchPosition.new(p_board, p_first_player)


## A deep copy that shares no mutable state with this position.
func copy() -> MatchPosition:
	return MatchPosition.new(board.copy(), first_player)
