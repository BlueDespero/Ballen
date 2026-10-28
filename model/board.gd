class_name Board
extends RefCounted

## The shared 6 x 6 grid of cells.
##
## A cell is a Vector2i(x, y): x is the column, 0-5 from the left; y is 0-5 from
## the top. Player 1's side is the top edge (y = 0) and player 0's side the
## bottom edge (y = 5). Row numbers for rules (1-6 from the first player's side)
## are derived from y and the first player (row_number); they are not stored here.

const SIZE: int = 6

const _EMPTY_CHAR: String = "."
## Board.parse letters: upper case is owned by player 0, lower case by player 1.
const _COLOUR_CHARS: Dictionary[String, String] = {
	BallColour.YELLOW: "y",
	BallColour.BLUE: "b",
	BallColour.RED: "r",
	BallColour.GREEN: "g",
}

# Index y * SIZE + x; null means an empty cell.
var _balls: Array[Ball] = []


func _init() -> void:
	_balls.resize(SIZE * SIZE)


static func contains(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < SIZE and cell.y >= 0 and cell.y < SIZE


static func all_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y: int in SIZE:
		for x: int in SIZE:
			cells.append(Vector2i(x, y))
	return cells


## True for the outer ring of cells.
static func is_on_edge(cell: Vector2i) -> bool:
	return cell.x == 0 or cell.y == 0 or cell.x == SIZE - 1 or cell.y == SIZE - 1


## The row number of a cell, 1-6 counted from the first player's side; both
## players use the same numbering.
static func row_number(cell: Vector2i, first_player: int) -> int:
	return SIZE - cell.y if first_player == 0 else cell.y + 1


## The up to 8 cells touching a cell, diagonals included; only cells on the board.
static func neighbours(cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var neighbour: Vector2i = cell + Vector2i(dx, dy)
			if neighbour != cell and contains(neighbour):
				cells.append(neighbour)
	return cells


## Builds a board from 6 strings of 6 characters, top row (y = 0) first.
## "." is empty; y, b, r, g are the colours; upper case belongs to player 0,
## lower case to player 1. Example row: "..Rb..".
static func parse(rows: PackedStringArray) -> Board:
	var board: Board = Board.new()
	if rows.size() != SIZE:
		push_error("Board.parse needs %d rows, got %d" % [SIZE, rows.size()])
		return board
	for y: int in SIZE:
		var row: String = rows[y]
		if row.length() != SIZE:
			push_error("Board.parse row %d needs %d cells: '%s'" % [y, SIZE, row])
			return board
		for x: int in SIZE:
			var symbol: String = row[x]
			if symbol == _EMPTY_CHAR:
				continue
			if not _COLOUR_CHARS.values().has(symbol.to_lower()):
				push_error("Board.parse: unknown cell '%s' in row %d" % [symbol, y])
				continue
			var colour: String = _COLOUR_CHARS.find_key(symbol.to_lower())
			var owner: int = 0 if symbol == symbol.to_upper() else 1
			board.place(Vector2i(x, y), Ball.new(colour, owner))
	return board


## The ball on a cell, or null when the cell is empty or off the board.
func ball_at(cell: Vector2i) -> Ball:
	if not contains(cell):
		return null
	return _balls[_index(cell)]


func is_empty(cell: Vector2i) -> bool:
	return contains(cell) and _balls[_index(cell)] == null


func place(cell: Vector2i, ball: Ball) -> void:
	if not is_empty(cell):
		push_error("Board.place: cell %s is not an empty cell" % cell)
		return
	_balls[_index(cell)] = ball


func empty_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in all_cells():
		if is_empty(cell):
			cells.append(cell)
	return cells


func is_full() -> bool:
	return empty_cells().is_empty()


## A deep copy: no ball is shared with this board.
func copy() -> Board:
	var board: Board = Board.new()
	for i: int in _balls.size():
		if _balls[i] != null:
			board._balls[i] = _balls[i].copy()
	return board


## A copy of this board with one more ball; this board is unchanged.
func with_ball(cell: Vector2i, ball: Ball) -> Board:
	var board: Board = copy()
	board.place(cell, ball)
	return board


func _index(cell: Vector2i) -> int:
	return cell.y * SIZE + cell.x
