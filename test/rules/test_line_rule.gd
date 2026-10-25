extends GutTest

# R10 "Never complete a line of 3" through the rule checker seam: the placement
# must not create 3 or more balls of one colour, either owner, in an unbroken
# straight line (horizontal, vertical or diagonal).

var _book: RuleBook


func before_each() -> void:
	_book = RuleBook.load_default()


func _legal(rows: PackedStringArray, holder: int, colour: String, cell: Vector2i) -> bool:
	var position: MatchPosition = MatchPosition.from_board(Board.parse(rows))
	return RuleChecker.is_legal(_book.rule("R10"), position, holder, colour, cell)


func test_completing_a_horizontal_line_at_its_end_is_illegal() -> void:
	var rows: PackedStringArray = [
		"......",
		"......",
		".RR...",
		"......",
		"......",
		"......",
	]
	assert_false(_legal(rows, 0, BallColour.RED, Vector2i(3, 2)))
	assert_false(_legal(rows, 0, BallColour.RED, Vector2i(0, 2)))


func test_completing_a_vertical_line_in_its_middle_is_illegal() -> void:
	var rows: PackedStringArray = [
		"......",
		"....b.",
		"......",
		"....b.",
		"......",
		"......",
	]
	assert_false(_legal(rows, 1, BallColour.BLUE, Vector2i(4, 2)))


func test_completing_a_down_right_diagonal_is_illegal() -> void:
	var rows: PackedStringArray = [
		"......",
		".G....",
		"..g...",
		"......",
		"......",
		"......",
	]
	assert_false(_legal(rows, 0, BallColour.GREEN, Vector2i(3, 3)))
	assert_false(_legal(rows, 0, BallColour.GREEN, Vector2i(0, 0)))


func test_completing_an_up_right_diagonal_in_its_middle_is_illegal() -> void:
	var rows: PackedStringArray = [
		"......",
		"......",
		"...Y..",
		"......",
		".y....",
		"......",
	]
	assert_false(_legal(rows, 1, BallColour.YELLOW, Vector2i(2, 3)))


func test_a_line_counts_balls_of_either_owner() -> void:
	var rows: PackedStringArray = [
		"......",
		"......",
		"......",
		"......",
		"......",
		"Rr....",
	]
	assert_false(_legal(rows, 0, BallColour.RED, Vector2i(2, 5)))
	assert_false(_legal(rows, 1, BallColour.RED, Vector2i(2, 5)))


func test_joining_two_pairs_into_a_line_longer_than_3_is_illegal() -> void:
	var rows: PackedStringArray = [
		"RR.RR.",
		"......",
		"......",
		"......",
		"......",
		"......",
	]
	assert_false(_legal(rows, 0, BallColour.RED, Vector2i(2, 0)))


func test_extending_a_line_of_3_is_illegal() -> void:
	var rows: PackedStringArray = [
		"......",
		"......",
		"......",
		"b.....",
		"b.....",
		"B.....",
	]
	assert_false(_legal(rows, 0, BallColour.BLUE, Vector2i(0, 2)))


func test_a_broken_line_is_no_line() -> void:
	var rows: PackedStringArray = [
		"......",
		"......",
		"RR.R..",
		"......",
		"......",
		"......",
	]
	assert_true(_legal(rows, 0, BallColour.RED, Vector2i(4, 2)))


func test_mixed_colours_make_no_line() -> void:
	var rows: PackedStringArray = [
		"......",
		"......",
		".RB...",
		"......",
		"..Y...",
		"......",
	]
	assert_true(_legal(rows, 0, BallColour.RED, Vector2i(0, 2)))
	assert_true(_legal(rows, 0, BallColour.BLUE, Vector2i(3, 2)))
	assert_true(_legal(rows, 0, BallColour.YELLOW, Vector2i(2, 3)))


func test_a_line_away_from_the_target_does_not_count() -> void:
	var rows: PackedStringArray = [
		"RRR...",
		"......",
		"......",
		"......",
		"......",
		"......",
	]
	assert_true(_legal(rows, 0, BallColour.RED, Vector2i(5, 0)))
	assert_true(_legal(rows, 0, BallColour.RED, Vector2i(1, 2)))


func test_legal_cells_leave_out_only_the_cells_that_complete_a_line() -> void:
	var rows: PackedStringArray = [
		"......",
		"......",
		"..gg..",
		"......",
		"......",
		"......",
	]
	var position: MatchPosition = MatchPosition.from_board(Board.parse(rows))
	var cells: Array[Vector2i] = RuleChecker.legal_cells(_book.rule("R10"), position, 1, BallColour.GREEN)
	assert_eq(cells.size(), 32)
	assert_false(cells.has(Vector2i(1, 2)))
	assert_false(cells.has(Vector2i(4, 2)))
	assert_eq(RuleChecker.legal_cells(_book.rule("R10"), position, 1, BallColour.RED).size(), 34)


func test_r10_carries_its_player_text() -> void:
	assert_eq(_book.rule("R10").text, "Never complete a line of 3")
	assert_eq(_book.rule("R10").template_id, "no_line_of")
