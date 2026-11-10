class_name CellMasks
extends RefCounted

## Precomputed cell masks (one bit per cell, y * 6 + x, as Board's masks) and
## bit helpers for the compiled rules (RuleCompiler).

const ALL: int = Board.ALL_CELLS_MASK

## The outer ring of cells.
static var edge: int = _edge()
## For each cell index, its neighbours (diagonals included, never itself).
static var neighbours: Array[int] = _within(1)
## For each cell index, every cell of its row, itself included.
static var row_of: Array[int] = _rows()
## For each n, for each cell index, the cells within n king steps, never itself.
static var _within_by_n: Dictionary[int, Array] = {}
## Cells that a shift by (dx, dy) can read from, by Vector2i(dx, dy).
static var _shift_valid: Dictionary[Vector2i, int] = {}


## The cells within n king steps of each cell, never the cell itself.
static func within(n: int) -> Array[int]:
	if not _within_by_n.has(n):
		_within_by_n[n] = _within(n)
	var masks: Array[int] = []
	masks.assign(_within_by_n[n])
	return masks


## The number of set bits.
static func popcount(mask: int) -> int:
	mask = mask - ((mask >> 1) & 0x5555555555555555)
	mask = (mask & 0x3333333333333333) + ((mask >> 2) & 0x3333333333333333)
	mask = (mask + (mask >> 4)) & 0x0F0F0F0F0F0F0F0F
	mask += mask >> 8
	mask += mask >> 16
	mask += mask >> 32
	return mask & 0x7F


## The cells whose row number (1-6 from the first player's side) passes:
## from..to, both included.
static func rows_between(first_player: int, from: int, to: int) -> int:
	var mask: int = 0
	for index: int in Board.SIZE * Board.SIZE:
		var row: int = Board.row_number(_cell(index), first_player)
		if row >= from and row <= to:
			mask |= 1 << index
	return mask


## The cells whose row number is even (remainder 0) or odd (remainder 1).
static func rows_with_parity(first_player: int, remainder: int) -> int:
	var mask: int = 0
	for index: int in Board.SIZE * Board.SIZE:
		if Board.row_number(_cell(index), first_player) % 2 == remainder:
			mask |= 1 << index
	return mask


## Bit (x, y) of the result is bit (x + dx, y + dy) of mask; 0 where that cell
## is off the board.
static func shifted(mask: int, dx: int, dy: int) -> int:
	var key: Vector2i = Vector2i(dx, dy)
	if not _shift_valid.has(key):
		var valid: int = 0
		for index: int in Board.SIZE * Board.SIZE:
			if Board.contains(_cell(index) + key):
				valid |= 1 << index
		_shift_valid[key] = valid
	var amount: int = dy * Board.SIZE + dx
	var moved: int = mask >> amount if amount >= 0 else mask << -amount
	return moved & _shift_valid[key] & ALL


## The cells next to (n = 1), or within n king steps of, any cell of mask.
static func spread(mask: int, tables: Array[int]) -> int:
	var result: int = 0
	var index: int = 0
	while mask != 0:
		if mask & 1:
			result |= tables[index]
		mask >>= 1
		index += 1
	return result


@warning_ignore("integer_division")
static func _cell(index: int) -> Vector2i:
	return Vector2i(index % Board.SIZE, index / Board.SIZE)


static func _edge() -> int:
	var mask: int = 0
	for index: int in Board.SIZE * Board.SIZE:
		if Board.is_on_edge(_cell(index)):
			mask |= 1 << index
	return mask


static func _within(n: int) -> Array[int]:
	var masks: Array[int] = []
	for index: int in Board.SIZE * Board.SIZE:
		var mask: int = 0
		for other: int in Board.SIZE * Board.SIZE:
			if other != index and Board.distance(_cell(index), _cell(other)) <= n:
				mask |= 1 << other
		masks.append(mask)
	return masks


static func _rows() -> Array[int]:
	var masks: Array[int] = []
	for index: int in Board.SIZE * Board.SIZE:
		var mask: int = 0
		for other: int in Board.SIZE * Board.SIZE:
			if _cell(other).y == _cell(index).y:
				mask |= 1 << other
		masks.append(mask)
	return masks
