extends GutTest

# The strictness check: the share of empty cells a rule forbids, on known
# positions and averaged over seeded random positions.

const Fixtures := preload("res://test/helpers/fixtures.gd")

var _book: RuleBook


func before_all() -> void:
	_book = Fixtures.book()


## A position at the given turn whose current player is to place colour.
func _position(rows: PackedStringArray, first_player: int, turn: int, colour: String) -> MatchPosition:
	var position: MatchPosition = MatchPosition.new(Board.parse(rows), first_player)
	position.turn = turn
	position.colour = colour
	return position


func _empty_board() -> PackedStringArray:
	return ["......", "......", "......", "......", "......", "......"]


func test_never_on_the_edge_forbids_the_20_edge_cells_of_an_empty_board() -> void:
	var position: MatchPosition = _position(_empty_board(), 0, 1, BallColour.RED)
	assert_almost_eq(StrictnessCheck.share_forbidden(_book.rule("R04"), position), 20.0 / 36.0, 1e-9)


func test_the_rule_is_judged_for_the_current_player() -> void:
	var rows: PackedStringArray = ["b.....", "......", "......", "......", "......", "......"]
	var r07: Rule = _book.rule("R07")
	assert_almost_eq(StrictnessCheck.share_forbidden(r07, _position(rows, 0, 1, BallColour.RED)), 3.0 / 35.0, 1e-9,
		"player 0's turn: the 3 neighbours of player 1's ball")
	assert_eq(StrictnessCheck.share_forbidden(r07, _position(rows, 0, 2, BallColour.RED)), 0.0,
		"player 1's turn: no opponent ball on the board")


## Every inner cell full: only the 20 edge cells are empty.
func _inner_cells_full() -> PackedStringArray:
	return ["......", ".YbRg.", ".RgYb.", ".YbRg.", ".RgYb.", "......"]


func test_strictness_is_the_average_share_over_the_positions() -> void:
	var positions: Array[MatchPosition] = [
		_position(_empty_board(), 0, 1, BallColour.RED),
		_position(_inner_cells_full(), 0, 17, BallColour.RED),
	]
	assert_almost_eq(StrictnessCheck.strictness(_book.rule("R04"), positions), (20.0 / 36.0 + 1.0) / 2.0, 1e-9,
		"each position weighs the same, however many empty cells it has")


func test_no_legal_cell_share_counts_the_positions_where_the_rule_forbids_every_empty_cell() -> void:
	var positions: Array[MatchPosition] = [
		_position(_empty_board(), 0, 1, BallColour.RED),
		_position(_inner_cells_full(), 0, 17, BallColour.RED),
		_position(_inner_cells_full(), 1, 17, BallColour.BLUE),
		_position(_empty_board(), 1, 2, BallColour.BLUE),
	]
	assert_eq(StrictnessCheck.no_legal_cell_share(_book.rule("R04"), positions), 0.5)
	assert_eq(StrictnessCheck.no_legal_cell_share(Fixtures.anywhere(_book, "AT"), positions), 0.0)


## A position as text: everything a rule can read, the board through its history.
func _describe(position: MatchPosition) -> String:
	var events: Array[String] = []
	for entry: HistoryEntry in position.history:
		events.append(str(entry))
	return "%d %d %s %s %s" % [position.first_player, position.turn, position.colour, position.skips, events]


func _describe_all(positions: Array[MatchPosition]) -> Array[String]:
	var texts: Array[String] = []
	for position: MatchPosition in positions:
		texts.append(_describe(position))
	return texts


func test_random_positions_are_the_same_for_the_same_seed() -> void:
	var first: Array[String] = _describe_all(StrictnessCheck.random_positions(20, 5))
	assert_eq(first.size(), 20)
	assert_eq(_describe_all(StrictnessCheck.random_positions(20, 5)), first)
	assert_ne(_describe_all(StrictnessCheck.random_positions(20, 6)), first)


func test_a_random_position_is_one_a_match_could_reach() -> void:
	for position: MatchPosition in StrictnessCheck.random_positions(100, 1):
		var board: Board = Board.new()
		var colour_picks: int = 0
		var skips: Array[int] = [0, 0]
		var picker: int = Players.opponent(position.first_player)
		for entry: HistoryEntry in position.history:
			match entry.type:
				HistoryEntry.Type.COLOUR_PICK:
					assert_eq(entry.player, picker, "players take turns, the second player picking first")
					picker = Players.opponent(picker)
					colour_picks += 1
				HistoryEntry.Type.PLACEMENT:
					assert_true(board.is_empty(entry.cell))
					board.place(entry.cell, Ball.new(entry.colour, entry.player))
				HistoryEntry.Type.SKIP:
					skips[entry.player] += 1
		assert_eq(position.history.back().type, HistoryEntry.Type.COLOUR_PICK, "the current player is to place")
		assert_eq(position.history.back().colour, position.colour)
		assert_eq(position.turn, colour_picks)
		assert_eq(position.skips, skips)
		assert_lt(skips.max(), Match.LOSING_SKIP, "a third skip would have ended the match")
		assert_eq(_balls(position.board), _balls(board), "the board holds exactly the history's placements")
		assert_false(position.board.is_full())


## Every cell's ball as "colour owner", "-" for an empty cell.
func _balls(board: Board) -> Array[String]:
	var balls: Array[String] = []
	for cell: Vector2i in Board.all_cells():
		var ball: Ball = board.ball_at(cell)
		balls.append("-" if ball == null else "%s %d" % [ball.colour, ball.owner])
	return balls


func test_random_positions_cover_every_fill_level_and_some_skips() -> void:
	var balls: Array[int] = []
	var with_skips: int = 0
	for position: MatchPosition in StrictnessCheck.random_positions(300, 1):
		balls.append(Board.SIZE * Board.SIZE - position.board.empty_cells().size())
		if position.skips[0] + position.skips[1] > 0:
			with_skips += 1
	assert_eq(balls.min(), 0, "an empty board")
	assert_eq(balls.max(), 35, "one empty cell left")
	assert_between(with_skips, 1, 299)


func test_the_summary_has_a_row_per_rule_and_flags_rules_outside_the_target_band() -> void:
	var positions: Array[MatchPosition] = [
		_position(_empty_board(), 0, 1, BallColour.RED),
		_position(_inner_cells_full(), 0, 17, BallColour.RED),
	]
	var rules: Array[Rule] = [_book.rule("R04"), Fixtures.anywhere(_book, "AT"), _book.rule("R01")]
	var lines: PackedStringArray = StrictnessCheck.summary(rules, positions).split("\n")
	assert_eq(lines[0], "Rule  Strictness  No legal cell  Band 20-60%")
	assert_eq(lines[1], "R04        77.8%          50.0%  above", "(20/36 + 1) / 2; no legal cell in the second")
	assert_eq(lines[2], "AT          0.0%           0.0%  below")
	# R01 forbids the 10 edge cells next to the reds at (3, 1), (1, 2) and (1, 4) of the second position.
	assert_eq(lines[3], "R01        25.0%           0.0%  in", "(0 + 10/20) / 2")
