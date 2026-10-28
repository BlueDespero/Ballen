extends GutTest

# Row rules through the rule checker seam. Rows are numbered 1-6 from the first
# player's side: player 0 sits at the bottom (y = 5), player 1 at the top (y = 0).

var _book: RuleBook


func before_each() -> void:
	_book = RuleBook.load_default()


func _position(rows: PackedStringArray) -> MatchPosition:
	return MatchPosition.new(Board.parse(rows))


func _rows_of(cells: Array[Vector2i]) -> Array[int]:
	var ys: Array[int] = []
	for cell: Vector2i in cells:
		if not ys.has(cell.y):
			ys.append(cell.y)
	ys.sort()
	return ys


# R03 Only on even rows ------------------------------------------------------

func test_r03_when_player_0_goes_first_allows_the_rows_y_4_2_and_0() -> void:
	var position: MatchPosition = MatchPosition.new(Board.new(), 0)
	var cells: Array[Vector2i] = RuleChecker.legal_cells(_book.rule("R03"), position, 0, BallColour.RED)
	assert_eq(cells.size(), 18)
	assert_eq(_rows_of(cells), [0, 2, 4] as Array[int])


func test_r03_when_player_1_goes_first_allows_the_rows_y_1_3_and_5() -> void:
	var position: MatchPosition = MatchPosition.new(Board.new(), 1)
	var cells: Array[Vector2i] = RuleChecker.legal_cells(_book.rule("R03"), position, 0, BallColour.RED)
	assert_eq(cells.size(), 18)
	assert_eq(_rows_of(cells), [1, 3, 5] as Array[int])


func test_r03_numbers_rows_the_same_for_both_holders() -> void:
	var rule: Rule = _book.rule("R03")
	for first_player: int in [0, 1]:
		var position: MatchPosition = MatchPosition.new(Board.new(), first_player)
		assert_eq(
			RuleChecker.legal_cells(rule, position, 1, BallColour.BLUE),
			RuleChecker.legal_cells(rule, position, 0, BallColour.BLUE),
			"first player %d" % first_player)


func test_r03_carries_its_player_text_and_data() -> void:
	var rule: Rule = _book.rule("R03")
	assert_eq(rule.text, "Only on even rows")
	assert_eq(rule.to_data(), {"id": "R03", "text": "Only on even rows", "template": "only_on_axis",
		"values": {"axis": "row", "parity": "even"}})


# R05 At most 2 of a colour in any row ---------------------------------------

func test_r05_forbids_a_third_ball_of_the_colour_in_a_row_of_either_owner() -> void:
	var position: MatchPosition = _position([
		"......",
		"......",
		"R...r.",
		"......",
		"......",
		"......",
	])
	var rule: Rule = _book.rule("R05")
	for holder: int in [0, 1]:
		assert_false(RuleChecker.is_legal(rule, position, holder, BallColour.RED, Vector2i(2, 2)), "holder %d" % holder)


func test_r05_allows_the_second_ball_of_the_colour_in_a_row() -> void:
	var position: MatchPosition = _position([
		"......",
		"......",
		"......",
		"..r...",
		"......",
		"......",
	])
	assert_true(RuleChecker.is_legal(_book.rule("R05"), position, 0, BallColour.RED, Vector2i(5, 3)))


func test_r05_counts_only_the_placed_colour() -> void:
	var position: MatchPosition = _position([
		"......",
		"......",
		"R.Bb.r",
		"......",
		"......",
		"......",
	])
	var rule: Rule = _book.rule("R05")
	assert_true(RuleChecker.is_legal(rule, position, 0, BallColour.YELLOW, Vector2i(1, 2)))
	assert_false(RuleChecker.is_legal(rule, position, 0, BallColour.BLUE, Vector2i(1, 2)))


func test_r05_looks_only_at_the_target_row() -> void:
	var position: MatchPosition = _position([
		"RRr...",
		"......",
		"..r...",
		"......",
		"......",
		"......",
	])
	var cells: Array[Vector2i] = RuleChecker.legal_cells(_book.rule("R05"), position, 1, BallColour.RED)
	# 32 empty cells; only the 3 empty cells of the top row are closed.
	assert_eq(cells.size(), 29)
	for x: int in [3, 4, 5]:
		assert_false(cells.has(Vector2i(x, 0)), "top row cell %d" % x)


func test_r05_carries_its_player_text_and_data() -> void:
	var rule: Rule = _book.rule("R05")
	assert_eq(rule.text, "At most 2 of a colour in any row")
	assert_eq(rule.to_data(), {"id": "R05", "text": "At most 2 of a colour in any row", "template": "max_in_axis",
		"values": {"axis": "row", "ball": "same_colour", "n": 2.0}}) # JSON numbers are floats
