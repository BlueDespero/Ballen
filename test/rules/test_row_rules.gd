extends GutTest

# Row rules through the rule checker seam. Rows are numbered 1-6 from the first
# player's side: player 0 sits at the bottom (y = 5), player 1 at the top (y = 0).

var _book: RuleBook


func before_each() -> void:
	_book = RuleBook.load_default()


func _rows_of(cells: Array[Vector2i]) -> Array[int]:
	var ys: Array[int] = []
	for cell: Vector2i in cells:
		if not ys.has(cell.y):
			ys.append(cell.y)
	ys.sort()
	return ys


# R03 Only on even rows ------------------------------------------------------

func test_r03_when_player_0_goes_first_allows_the_rows_y_4_2_and_0() -> void:
	var position: MatchPosition = MatchPosition.from_board(Board.new(), 0)
	var cells: Array[Vector2i] = RuleChecker.legal_cells(_book.rule("R03"), position, 0, BallColour.RED)
	assert_eq(cells.size(), 18)
	assert_eq(_rows_of(cells), [0, 2, 4] as Array[int])


func test_r03_when_player_1_goes_first_allows_the_rows_y_1_3_and_5() -> void:
	var position: MatchPosition = MatchPosition.from_board(Board.new(), 1)
	var cells: Array[Vector2i] = RuleChecker.legal_cells(_book.rule("R03"), position, 0, BallColour.RED)
	assert_eq(cells.size(), 18)
	assert_eq(_rows_of(cells), [1, 3, 5] as Array[int])


func test_r03_numbers_rows_the_same_for_both_holders() -> void:
	var rule: Rule = _book.rule("R03")
	for first_player: int in [0, 1]:
		var position: MatchPosition = MatchPosition.from_board(Board.new(), first_player)
		assert_eq(
			RuleChecker.legal_cells(rule, position, 1, BallColour.BLUE),
			RuleChecker.legal_cells(rule, position, 0, BallColour.BLUE),
			"first player %d" % first_player)


func test_r03_carries_its_player_text_and_data() -> void:
	var rule: Rule = _book.rule("R03")
	assert_eq(rule.text, "Only on even rows")
	assert_eq(rule.to_data(), {"id": "R03", "text": "Only on even rows", "template": "only_on_axis",
		"values": {"axis": "row", "parity": "even"}})
