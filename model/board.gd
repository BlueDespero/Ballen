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

## Every cell's bit in a cell mask: bit y * SIZE + x, the same order as _balls.
const ALL_CELLS_MASK: int = (1 << (SIZE * SIZE)) - 1

# Index y * SIZE + x; null means an empty cell.
var _balls: Array[Ball] = []
# Bit masks of the same cells (see ALL_CELLS_MASK), kept in step with _balls
# for the compiled rules (RuleCompiler).
var _occupied: int = 0
var _colour_masks: Dictionary[String, int] = {}
var _owner_masks: Array[int] = [0, 0]


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


## The distance between two cells in king moves (one step reaches any
## neighbour, diagonals included): neighbours are 1 apart.
static func distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


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
	var bit: int = 1 << _index(cell)
	_occupied |= bit
	_colour_masks[ball.colour] = _colour_masks.get(ball.colour, 0) | bit
	_owner_masks[ball.owner] |= bit


## Empties a cell (no-op if it is empty or off the board). For trying
## placements on a scratch copy; a match never removes a ball.
func remove(cell: Vector2i) -> void:
	if not contains(cell) or _balls[_index(cell)] == null:
		return
	var ball: Ball = _balls[_index(cell)]
	_balls[_index(cell)] = null
	var bit: int = 1 << _index(cell)
	_occupied &= ~bit
	_colour_masks[ball.colour] &= ~bit
	_owner_masks[ball.owner] &= ~bit


## The cells holding a ball, as a cell mask (see ALL_CELLS_MASK).
func occupied_mask() -> int:
	return _occupied


## The cells holding a ball of this colour, either owner, as a cell mask.
func colour_mask(colour: String) -> int:
	return _colour_masks.get(colour, 0)


## The cells holding a ball owned by this player, as a cell mask.
func owner_mask(owner: int) -> int:
	return _owner_masks[owner]


## A cell's bit in a cell mask.
static func bit(cell: Vector2i) -> int:
	return 1 << (cell.y * SIZE + cell.x)


## The cells of a cell mask, in the order empty_cells and all_cells list them.
@warning_ignore("integer_division")
static func cells_of(mask: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var index: int = 0
	while mask != 0:
		if mask & 1:
			cells.append(Vector2i(index % SIZE, index / SIZE))
		mask >>= 1
		index += 1
	return cells


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
	board._occupied = _occupied
	board._colour_masks = _colour_masks.duplicate()
	board._owner_masks = _owner_masks.duplicate()
	return board


## A copy of this board with one more ball; this board is unchanged.
func with_ball(cell: Vector2i, ball: Ball) -> Board:
	var board: Board = copy()
	board.place(cell, ball)
	return board


func _index(cell: Vector2i) -> int:
	return cell.y * SIZE + cell.x
