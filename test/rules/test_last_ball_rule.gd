extends GutTest

# R08 "Not next to the ball you placed last" and R23 "Never next to the
# opponent's last ball", through the rule checker seam. A player's last ball
# comes from the position's history: their most recent placement.

var _book: RuleBook


func before_each() -> void:
	_book = RuleBook.load_default()


func _position(rows: PackedStringArray, history: Array[HistoryEntry]) -> MatchPosition:
	var position: MatchPosition = MatchPosition.new(Board.parse(rows))
	position.history = history
	return position


func test_r08_forbids_every_neighbour_of_the_holders_last_ball() -> void:
	var position: MatchPosition = _position([
		"......",
		"......",
		"..R...",
		"......",
		"......",
		"......",
	], [HistoryEntry.placement(0, Vector2i(2, 2), BallColour.RED)])
	var cells: Array[Vector2i] = RuleChecker.legal_cells(_book.rule("R08"), position, 0, BallColour.BLUE)
	var forbidden: Array[Vector2i] = [
		Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
		Vector2i(1, 2), Vector2i(3, 2),
		Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3),
	]
	assert_eq(cells.size(), 27)
	for cell: Vector2i in forbidden:
		assert_false(cells.has(cell), "neighbour %s" % cell)


func test_r08_allows_every_empty_cell_before_the_holders_first_placement() -> void:
	var position: MatchPosition = _position([
		"......",
		"......",
		"..r...",
		"......",
		"......",
		"......",
	], [
		HistoryEntry.colour_pick(0, BallColour.RED),
		HistoryEntry.placement(1, Vector2i(2, 2), BallColour.RED),
		HistoryEntry.colour_pick(1, BallColour.BLUE),
	])
	assert_eq(RuleChecker.legal_cells(_book.rule("R08"), position, 0, BallColour.BLUE).size(), 35)


func test_r08_looks_only_at_the_holders_most_recent_ball() -> void:
	var position: MatchPosition = _position([
		"Y.....",
		"......",
		"......",
		"......",
		"....r.",
		".....G",
	], [
		HistoryEntry.placement(0, Vector2i(0, 0), BallColour.YELLOW),
		HistoryEntry.placement(0, Vector2i(5, 5), BallColour.GREEN),
		HistoryEntry.placement(1, Vector2i(4, 4), BallColour.RED),
	])
	var rule: Rule = _book.rule("R08")
	assert_true(RuleChecker.is_legal(rule, position, 0, BallColour.BLUE, Vector2i(1, 1)), "next to an older own ball")
	assert_true(RuleChecker.is_legal(rule, position, 0, BallColour.BLUE, Vector2i(3, 3)), "next to the opponent's last ball")
	assert_false(RuleChecker.is_legal(rule, position, 0, BallColour.BLUE, Vector2i(4, 5)), "next to the last ball")
	assert_false(RuleChecker.is_legal(rule, position, 0, BallColour.BLUE, Vector2i(5, 4)), "next to the last ball")


func test_r08_for_player_1_looks_at_player_1s_last_ball() -> void:
	var position: MatchPosition = _position([
		"......",
		".b....",
		"......",
		"......",
		"....R.",
		"......",
	], [
		HistoryEntry.placement(1, Vector2i(1, 1), BallColour.BLUE),
		HistoryEntry.placement(0, Vector2i(4, 4), BallColour.RED),
	])
	var rule: Rule = _book.rule("R08")
	assert_false(RuleChecker.is_legal(rule, position, 1, BallColour.GREEN, Vector2i(0, 0)), "diagonal into the corner")
	assert_true(RuleChecker.is_legal(rule, position, 1, BallColour.GREEN, Vector2i(5, 5)), "next to the opponent's ball")
	assert_eq(RuleChecker.legal_cells(rule, position, 1, BallColour.GREEN).size(), 26)


func test_r08_ignores_colour_picks_after_the_holders_last_placement() -> void:
	var position: MatchPosition = _position([
		"......",
		"......",
		"......",
		"...B..",
		"......",
		"......",
	], [
		HistoryEntry.placement(0, Vector2i(3, 3), BallColour.BLUE),
		HistoryEntry.colour_pick(0, BallColour.GREEN),
		HistoryEntry.colour_pick(1, BallColour.RED),
	])
	var rule: Rule = _book.rule("R08")
	assert_false(RuleChecker.is_legal(rule, position, 0, BallColour.RED, Vector2i(2, 4)))
	assert_eq(RuleChecker.legal_cells(rule, position, 0, BallColour.RED).size(), 27)


func test_a_skip_by_the_holder_leaves_their_last_ball_unchanged() -> void:
	var position: MatchPosition = _position([
		"......",
		"......",
		"......",
		"...B..",
		"......",
		"......",
	], [
		HistoryEntry.placement(0, Vector2i(3, 3), BallColour.BLUE),
		HistoryEntry.colour_pick(0, BallColour.GREEN),
		HistoryEntry.skip(1, BallColour.GREEN),
		HistoryEntry.colour_pick(1, BallColour.YELLOW),
		HistoryEntry.skip(0, BallColour.YELLOW),
		HistoryEntry.colour_pick(0, BallColour.RED),
		HistoryEntry.colour_pick(1, BallColour.RED),
	])
	var rule: Rule = _book.rule("R08")
	assert_false(RuleChecker.is_legal(rule, position, 0, BallColour.RED, Vector2i(4, 2)), "still next to the last ball")
	assert_eq(RuleChecker.legal_cells(rule, position, 0, BallColour.RED).size(), 27)


func test_r08_carries_its_player_text() -> void:
	assert_eq(_book.rule("R08").text, "Not next to the ball you placed last")


# R23 Never next to the opponent's last ball ---------------------------------

func test_r23_forbids_every_neighbour_of_the_opponents_last_ball() -> void:
	var position: MatchPosition = _position([
		"......",
		"......",
		"..r...",
		"......",
		"....Y.",
		"......",
	], [
		HistoryEntry.placement(0, Vector2i(4, 4), BallColour.YELLOW),
		HistoryEntry.placement(1, Vector2i(2, 2), BallColour.RED),
	])
	var cells: Array[Vector2i] = RuleChecker.legal_cells(_book.rule("R23"), position, 0, BallColour.BLUE)
	assert_eq(cells.size(), 26)
	for cell: Vector2i in Board.neighbours(Vector2i(2, 2)):
		assert_false(cells.has(cell), "neighbour %s of the opponent's last ball" % cell)
	assert_true(cells.has(Vector2i(5, 5)), "next to the holder's own last ball")


func test_r23_allows_every_empty_cell_before_the_opponents_first_placement() -> void:
	var position: MatchPosition = _position([
		"......",
		"......",
		"..R...",
		"......",
		"......",
		"......",
	], [
		HistoryEntry.colour_pick(1, BallColour.RED),
		HistoryEntry.placement(0, Vector2i(2, 2), BallColour.RED),
		HistoryEntry.colour_pick(0, BallColour.BLUE),
	])
	assert_eq(RuleChecker.legal_cells(_book.rule("R23"), position, 0, BallColour.BLUE).size(), 35)


func test_r23_for_player_1_looks_at_player_0s_most_recent_ball() -> void:
	var position: MatchPosition = _position([
		"Y.....",
		"......",
		"......",
		"......",
		"....b.",
		".....G",
	], [
		HistoryEntry.placement(0, Vector2i(0, 0), BallColour.YELLOW),
		HistoryEntry.placement(1, Vector2i(4, 4), BallColour.BLUE),
		HistoryEntry.placement(0, Vector2i(5, 5), BallColour.GREEN),
		HistoryEntry.colour_pick(0, BallColour.RED),
	])
	var rule: Rule = _book.rule("R23")
	assert_true(RuleChecker.is_legal(rule, position, 1, BallColour.RED, Vector2i(1, 1)), "next to an older opponent ball")
	assert_false(RuleChecker.is_legal(rule, position, 1, BallColour.RED, Vector2i(5, 4)), "next to the opponent's last ball")
	assert_eq(RuleChecker.legal_cells(rule, position, 1, BallColour.RED).size(), 31)


func test_r23_carries_its_player_text() -> void:
	assert_eq(_book.rule("R23").text, "Never next to the opponent's last ball")
