extends GutTest

# "Must touch" rules through the rule checker seam: the placed ball must land on
# a neighbour of a ball of some kind. With no such ball on the board there is
# nothing to touch, and the rule allows every empty cell.

var _book: RuleBook


func before_each() -> void:
	_book = RuleBook.load_default()


func _position(rows: PackedStringArray) -> MatchPosition:
	return MatchPosition.new(Board.parse(rows))


func _sorted(cells: Array[Vector2i]) -> Array[Vector2i]:
	var copy: Array[Vector2i] = cells.duplicate()
	copy.sort()
	return copy


# R13 Must touch an existing ball --------------------------------------------

func test_r13_allows_only_the_neighbours_of_the_balls_on_the_board() -> void:
	var position: MatchPosition = _position([
		"r.....",
		"......",
		"......",
		"......",
		"....B.",
		"......",
	])
	var expected: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1),
		Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3),
		Vector2i(3, 4), Vector2i(5, 4),
		Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5),
	]
	var cells: Array[Vector2i] = RuleChecker.legal_cells(_book.rule("R13"), position, 0, BallColour.GREEN)
	assert_eq(_sorted(cells), _sorted(expected))


func test_r13_on_an_empty_board_allows_every_cell() -> void:
	var position: MatchPosition = MatchPosition.new(Board.new())
	assert_eq(RuleChecker.legal_cells(_book.rule("R13"), position, 0, BallColour.RED).size(), 36)


func test_r13_carries_its_player_text() -> void:
	assert_eq(_book.rule("R13").text, "Must touch an existing ball")


# R14 Must join your own group -----------------------------------------------

func test_r14_allows_only_the_neighbours_of_the_holders_balls() -> void:
	var position: MatchPosition = _position([
		"......",
		".y....",
		"......",
		"......",
		"......",
		".....G",
	])
	var expected: Array[Vector2i] = [Vector2i(4, 4), Vector2i(5, 4), Vector2i(4, 5)]
	var cells: Array[Vector2i] = RuleChecker.legal_cells(_book.rule("R14"), position, 0, BallColour.RED)
	assert_eq(_sorted(cells), _sorted(expected))


func test_r14_for_player_1_looks_at_player_1s_balls() -> void:
	var position: MatchPosition = _position([
		"y.....",
		"......",
		"......",
		"......",
		"......",
		".....G",
	])
	var expected: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	var cells: Array[Vector2i] = RuleChecker.legal_cells(_book.rule("R14"), position, 1, BallColour.RED)
	assert_eq(_sorted(cells), _sorted(expected))


func test_r14_allows_every_empty_cell_while_the_holder_has_no_ball_on_the_board() -> void:
	var position: MatchPosition = _position([
		"......",
		"..bb..",
		"......",
		"......",
		"......",
		"......",
	])
	assert_eq(RuleChecker.legal_cells(_book.rule("R14"), position, 0, BallColour.BLUE).size(), 34)


func test_r14_carries_its_player_text() -> void:
	assert_eq(_book.rule("R14").text, "Must join your own group")
