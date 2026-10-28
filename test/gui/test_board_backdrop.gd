extends GutTest

# The menu backdrop: dim board cells where balls drop in, rest and
# fade, about 8 to 12 at a time; with reduced motion a still scatter instead.

const STEP: float = 1.0 / 60.0


func _backdrop(reduced_motion: bool, seed_value: int = 7, rect_size: Vector2 = Vector2(1280, 720)) -> BoardBackdrop:
	var backdrop: BoardBackdrop = BoardBackdrop.new()
	add_child_autofree(backdrop)
	backdrop.size = rect_size
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	backdrop.rng = rng
	backdrop.reduced_motion = reduced_motion
	backdrop.start()
	return backdrop


func _cells(backdrop: BoardBackdrop) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for ball: BoardBackdrop.FallingBall in backdrop.balls:
		cells.append(ball.cell)
	return cells


func _assert_distinct_cells_inside(backdrop: BoardBackdrop) -> void:
	var across: Vector2i = backdrop.cells_across()
	var cells: Array[Vector2i] = _cells(backdrop)
	for i: int in cells.size():
		var cell: Vector2i = cells[i]
		assert_true(cell.x >= 0 and cell.y >= 0 and cell.x < across.x and cell.y < across.y, "%s is in the rect" % cell)
		assert_false(cells.slice(i + 1).has(cell), "%s holds one ball" % cell)


func test_the_cells_cover_the_whole_rect() -> void:
	assert_eq(_backdrop(true).cells_across(), Vector2i(16, 9))
	assert_eq(_backdrop(true, 7, Vector2(736, 720)).cells_across(), Vector2i(10, 9), "partial cells at the edges")
	assert_true(_backdrop(true).clip_contents, "partial cells are cut at the rect")


func test_it_never_takes_the_mouse() -> void:
	assert_eq(_backdrop(false).mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_it_starts_already_full_of_balls() -> void:
	var count: int = _backdrop(false).balls.size()
	assert_between(count, BoardBackdrop.MIN_BALLS, BoardBackdrop.MAX_BALLS)


func test_balls_keep_coming_and_going_with_8_to_12_on_screen() -> void:
	var backdrop: BoardBackdrop = _backdrop(false)
	var first_cells: Array[Vector2i] = _cells(backdrop)
	for frame: int in 60 * 20:
		backdrop.advance(STEP)
		assert_between(backdrop.balls.size(), BoardBackdrop.MIN_BALLS, BoardBackdrop.MAX_BALLS)
	assert_ne(_cells(backdrop), first_cells, "the balls changed")
	_assert_distinct_cells_inside(backdrop)


func test_a_ball_lands_in_an_empty_cell() -> void:
	var backdrop: BoardBackdrop = _backdrop(false, 3, Vector2(160, 160))
	for frame: int in 60 * 20:
		backdrop.advance(STEP)
		_assert_distinct_cells_inside(backdrop)


func test_balls_come_in_the_ball_colours() -> void:
	var backdrop: BoardBackdrop = _backdrop(false)
	for ball: BoardBackdrop.FallingBall in backdrop.balls:
		assert_has(BallColour.ALL, ball.colour)


func test_a_ball_drops_with_an_ease_out_then_rests() -> void:
	var drop_time: float = BoardBackdrop.DROP_SECONDS
	assert_eq(BoardBackdrop.fall(0.0), 1.0, "starts a full drop above its cell")
	assert_gt(1.0 - BoardBackdrop.fall(drop_time / 2.0), 0.5, "more than half the way down at half time")
	assert_eq(BoardBackdrop.fall(drop_time), 0.0, "rests on its cell")
	assert_eq(BoardBackdrop.fall(BoardBackdrop.LIFETIME), 0.0)


func test_a_ball_rests_then_fades_out() -> void:
	var fade_start: float = BoardBackdrop.LIFETIME - BoardBackdrop.FADE_SECONDS
	assert_eq(BoardBackdrop.alpha(BoardBackdrop.DROP_SECONDS), 1.0)
	assert_eq(BoardBackdrop.alpha(fade_start), 1.0)
	assert_lt(BoardBackdrop.alpha(fade_start + BoardBackdrop.FADE_SECONDS / 2.0), 1.0)
	assert_eq(BoardBackdrop.alpha(BoardBackdrop.LIFETIME), 0.0)


func test_a_faded_ball_is_gone() -> void:
	var backdrop: BoardBackdrop = _backdrop(false)
	backdrop.advance(BoardBackdrop.LIFETIME)
	for ball: BoardBackdrop.FallingBall in backdrop.balls:
		assert_lt(ball.age, BoardBackdrop.LIFETIME)


func test_the_same_seed_gives_the_same_balls() -> void:
	assert_eq(_cells(_backdrop(false, 11)), _cells(_backdrop(false, 11)))
	assert_ne(_cells(_backdrop(false, 11)), _cells(_backdrop(false, 12)))


func test_reduced_motion_shows_a_still_scatter() -> void:
	var backdrop: BoardBackdrop = _backdrop(true)
	assert_eq(backdrop.balls.size(), BoardBackdrop.SCATTER_BALLS)
	_assert_distinct_cells_inside(backdrop)
	var cells: Array[Vector2i] = _cells(backdrop)
	backdrop.advance(BoardBackdrop.LIFETIME * 3.0)
	assert_eq(_cells(backdrop), cells, "nothing moves")
	for ball: BoardBackdrop.FallingBall in backdrop.balls:
		assert_eq(BoardBackdrop.fall(ball.age), 0.0)
		assert_eq(BoardBackdrop.alpha(ball.age), 1.0)


func test_turning_motion_back_on_starts_the_balls_falling_again() -> void:
	var backdrop: BoardBackdrop = _backdrop(true)
	backdrop.reduced_motion = false
	backdrop.start()
	var cells: Array[Vector2i] = _cells(backdrop)
	backdrop.advance(BoardBackdrop.LIFETIME)
	assert_ne(_cells(backdrop), cells)


func test_a_smaller_rect_loses_the_balls_outside_it() -> void:
	var backdrop: BoardBackdrop = _backdrop(false)
	var before: int = backdrop.balls.size()
	backdrop.size = Vector2(320, 240)
	assert_lt(backdrop.balls.size(), before, "balls outside the 4 x 3 cells are gone")
	_assert_distinct_cells_inside(backdrop)
	backdrop.advance(BoardBackdrop.LIFETIME)
	assert_gt(backdrop.balls.size(), 0, "new balls drop onto the smaller rect")
	_assert_distinct_cells_inside(backdrop)
