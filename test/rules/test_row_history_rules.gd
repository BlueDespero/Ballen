extends GutTest

# Row rules that look at the holder's last ball, and R19, through the rule
# checker seam. Rows are numbered 1-6 from the first player's side: row = 6 - y
# when player 0 goes first, y + 1 when player 1 does. The last ball comes from
# the position's history: the holder's most recent placement.

var _book: RuleBook


func before_each() -> void:
	_book = RuleBook.load_default()


func _position(rows: PackedStringArray, first_player: int, history: Array[HistoryEntry]) -> MatchPosition:
	var position: MatchPosition = MatchPosition.new(Board.parse(rows), first_player)
	position.history = history
	return position


## Player 0's last ball at (2, 2): row 4 when player 0 goes first, row 3 when
## player 1 does. Player 1's last ball at (4, 4).
func _last_ball_at_y_2(first_player: int) -> MatchPosition:
	return _position([
		"......",
		"......",
		"..R...",
		"......",
		"....r.",
		"......",
	], first_player, [
		HistoryEntry.placement(0, Vector2i(2, 2), BallColour.RED),
		HistoryEntry.placement(1, Vector2i(4, 4), BallColour.RED),
	])


func _rows_of(cells: Array[Vector2i]) -> Array[int]:
	var ys: Array[int] = []
	for cell: Vector2i in cells:
		if not ys.has(cell.y):
			ys.append(cell.y)
	ys.sort()
	return ys


# R09 Never in the same row as your last ball ---------------------------------

func test_r09_forbids_the_row_of_the_holders_last_ball_for_either_first_player() -> void:
	for first_player: int in [0, 1]:
		var cells: Array[Vector2i] = RuleChecker.legal_cells(
			_book.rule("R09"), _last_ball_at_y_2(first_player), 0, BallColour.BLUE)
		assert_eq(cells.size(), 29, "first player %d" % first_player)
		assert_eq(_rows_of(cells), [0, 1, 3, 4, 5] as Array[int], "first player %d" % first_player)


func test_r09_for_player_1_forbids_the_row_of_player_1s_last_ball() -> void:
	var cells: Array[Vector2i] = RuleChecker.legal_cells(_book.rule("R09"), _last_ball_at_y_2(1), 1, BallColour.BLUE)
	assert_eq(_rows_of(cells), [0, 1, 2, 3, 5] as Array[int])


func test_r09_allows_every_empty_cell_before_the_holders_first_placement() -> void:
	var position: MatchPosition = _position([
		"......",
		"......",
		"..r...",
		"......",
		"......",
		"......",
	], 1, [HistoryEntry.placement(1, Vector2i(2, 2), BallColour.RED)])
	assert_eq(RuleChecker.legal_cells(_book.rule("R09"), position, 0, BallColour.BLUE).size(), 35)


func test_r09_carries_its_player_text_and_data() -> void:
	var rule: Rule = _book.rule("R09")
	assert_eq(rule.text, "Never in the same row as your last ball")
	assert_eq(rule.to_data(), {"id": "R09", "text": "Never in the same row as your last ball",
		"template": "not_same_axis_as", "values": {"axis": "row", "ball": "my_last_ball"}})


# R15 Only in a row numbered higher than your last ball's row ------------------

func test_r15_when_player_0_goes_first_allows_rows_5_and_6_after_a_last_ball_in_row_4() -> void:
	var cells: Array[Vector2i] = RuleChecker.legal_cells(_book.rule("R15"), _last_ball_at_y_2(0), 0, BallColour.BLUE)
	assert_eq(_rows_of(cells), [0, 1] as Array[int])


func test_r15_when_player_1_goes_first_allows_rows_4_to_6_after_a_last_ball_in_row_3() -> void:
	var cells: Array[Vector2i] = RuleChecker.legal_cells(_book.rule("R15"), _last_ball_at_y_2(1), 0, BallColour.BLUE)
	assert_eq(_rows_of(cells), [3, 4, 5] as Array[int])


func test_r15_for_player_1_compares_with_player_1s_last_ball() -> void:
	# Player 1's last ball at y 4: row 2 when player 0 goes first, row 5 when player 1 does.
	var rule: Rule = _book.rule("R15")
	assert_eq(_rows_of(RuleChecker.legal_cells(rule, _last_ball_at_y_2(0), 1, BallColour.BLUE)),
		[0, 1, 2, 3] as Array[int])
	assert_eq(_rows_of(RuleChecker.legal_cells(rule, _last_ball_at_y_2(1), 1, BallColour.BLUE)),
		[5] as Array[int])


func test_r15_allows_no_cell_after_a_last_ball_in_row_6() -> void:
	for first_player: int in [0, 1]:
		var y: int = 0 if first_player == 0 else 5
		var position: MatchPosition = MatchPosition.new(
			Board.new().with_ball(Vector2i(3, y), Ball.new(BallColour.RED, 0)), first_player)
		position.history = [HistoryEntry.placement(0, Vector2i(3, y), BallColour.RED)]
		assert_eq(RuleChecker.legal_cells(_book.rule("R15"), position, 0, BallColour.BLUE).size(), 0,
			"first player %d" % first_player)


func test_r15_allows_every_empty_cell_before_the_holders_first_placement() -> void:
	for first_player: int in [0, 1]:
		var position: MatchPosition = _position([
			"......",
			"......",
			"......",
			"......",
			"....r.",
			"......",
		], first_player, [HistoryEntry.placement(1, Vector2i(4, 4), BallColour.RED)])
		assert_eq(RuleChecker.legal_cells(_book.rule("R15"), position, 0, BallColour.BLUE).size(), 35,
			"first player %d" % first_player)


func test_r15_carries_its_player_text_and_data() -> void:
	var rule: Rule = _book.rule("R15")
	assert_eq(rule.text, "Only in a row numbered higher than your last ball's row")
	assert_eq(rule.to_data(), {"id": "R15", "text": "Only in a row numbered higher than your last ball's row",
		"template": "relative_to_last", "values": {"direction": "higher"}})
