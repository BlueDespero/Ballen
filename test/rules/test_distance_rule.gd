extends GutTest

# R11 "At least 2 cells from any red", through the rule checker seam. Distance
# counts king moves (diagonals included, like neighbours): no red ball may lie
# within 2 steps of the target, the 5 x 5 square around it.

var _book: RuleBook


func before_each() -> void:
	_book = RuleBook.load_default()


func _position(rows: PackedStringArray) -> MatchPosition:
	return MatchPosition.new(Board.parse(rows))


func test_r11_forbids_the_5_by_5_square_around_a_red_ball() -> void:
	var position: MatchPosition = _position([
		"......",
		"......",
		"..r...",
		"......",
		"......",
		"......",
	])
	var cells: Array[Vector2i] = RuleChecker.legal_cells(_book.rule("R11"), position, 0, BallColour.BLUE)
	assert_eq(cells.size(), 11)
	for cell: Vector2i in cells:
		assert_true(cell.x == 5 or cell.y == 5, "%s is 3 steps from the red ball" % cell)


func test_r11_judges_by_king_steps_to_red_balls_of_either_owner() -> void:
	var position: MatchPosition = _position([
		"R.....",
		"......",
		"......",
		"......",
		"......",
		".....r",
	])
	var rule: Rule = _book.rule("R11")
	assert_false(RuleChecker.is_legal(rule, position, 0, BallColour.GREEN, Vector2i(2, 2)), "2 diagonal steps from (0, 0)")
	assert_false(RuleChecker.is_legal(rule, position, 0, BallColour.GREEN, Vector2i(3, 5)), "2 steps from (5, 5)")
	assert_true(RuleChecker.is_legal(rule, position, 0, BallColour.GREEN, Vector2i(3, 0)), "3 steps from (0, 0)")
	assert_true(RuleChecker.is_legal(rule, position, 0, BallColour.GREEN, Vector2i(2, 3)), "3 steps from both")


func test_r11_ignores_balls_of_other_colours() -> void:
	var position: MatchPosition = _position([
		"......",
		".yb...",
		".Gg...",
		"......",
		"......",
		"......",
	])
	assert_eq(RuleChecker.legal_cells(_book.rule("R11"), position, 0, BallColour.YELLOW).size(), 32)


func test_r11_lets_a_red_ball_go_anywhere_on_a_board_without_red() -> void:
	var position: MatchPosition = MatchPosition.new(Board.new())
	assert_eq(RuleChecker.legal_cells(_book.rule("R11"), position, 0, BallColour.RED).size(), 36)


func test_r11_carries_its_player_text() -> void:
	assert_eq(_book.rule("R11").text, "At least 2 cells from any red")
