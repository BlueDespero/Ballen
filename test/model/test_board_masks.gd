extends GutTest

# The board's cell masks (one bit per cell, y * 6 + x) stay in step with its
# balls through placing, removing and copying.


func _board() -> Board:
	return Board.parse(PackedStringArray([
		"R.....",
		"..b...",
		"......",
		"...G..",
		"......",
		".....y",
	]))


func test_masks_follow_the_balls_placed() -> void:
	var board: Board = _board()
	assert_eq(Board.cells_of(board.occupied_mask()),
		[Vector2i(0, 0), Vector2i(2, 1), Vector2i(3, 3), Vector2i(5, 5)] as Array[Vector2i])
	assert_eq(Board.cells_of(board.colour_mask(BallColour.RED)), [Vector2i(0, 0)] as Array[Vector2i])
	assert_eq(board.colour_mask(BallColour.YELLOW), Board.bit(Vector2i(5, 5)))
	assert_eq(Board.cells_of(board.owner_mask(0)), [Vector2i(0, 0), Vector2i(3, 3)] as Array[Vector2i])
	assert_eq(Board.cells_of(board.owner_mask(1)), [Vector2i(2, 1), Vector2i(5, 5)] as Array[Vector2i])


func test_removing_a_ball_clears_its_bits() -> void:
	var board: Board = _board()
	board.remove(Vector2i(2, 1))
	board.remove(Vector2i(4, 4))
	assert_eq(board.colour_mask(BallColour.BLUE), 0)
	assert_eq(board.owner_mask(1), Board.bit(Vector2i(5, 5)))
	assert_eq(Board.cells_of(board.occupied_mask()).size(), 3)


func test_a_copy_keeps_its_own_masks() -> void:
	var board: Board = _board()
	var copied: Board = board.copy()
	copied.place(Vector2i(1, 1), Ball.new(BallColour.RED, 1))
	assert_eq(Board.cells_of(board.colour_mask(BallColour.RED)), [Vector2i(0, 0)] as Array[Vector2i])
	assert_eq(Board.cells_of(copied.colour_mask(BallColour.RED)), [Vector2i(0, 0), Vector2i(1, 1)] as Array[Vector2i])


func test_the_empty_cells_are_the_cells_outside_the_occupied_mask() -> void:
	var board: Board = _board()
	assert_eq(Board.cells_of(Board.ALL_CELLS_MASK & ~board.occupied_mask()), board.empty_cells())
