extends GutTest

# Time and game-state rules (R20, R21, R22) through the rule checker seam.
# Turns: odd match turns are the first player's, even ones the other player's;
# "your n-th turn" counts only the holder's turns.
# Board.parse: upper case = player 0, lower case = player 1.

const EDGE_CELLS: int = 20
const INNER_CELLS: int = 16

var _book: RuleBook


func before_each() -> void:
	_book = RuleBook.load_default()


func _position(first_player: int, turn: int) -> MatchPosition:
	var position: MatchPosition = MatchPosition.new(Board.new(), first_player)
	position.turn = turn
	return position


# R20 On your odd turns, edge only -------------------------------------------

func test_r20_on_the_first_players_first_turn_allows_only_the_edge() -> void:
	var cells: Array[Vector2i] = RuleChecker.legal_cells(_book.rule("R20"), _position(0, 1), 0, BallColour.RED)
	assert_eq(cells.size(), EDGE_CELLS)
	for cell: Vector2i in cells:
		assert_true(Board.is_on_edge(cell), str(cell))


func test_r20_on_the_first_players_second_turn_allows_every_cell() -> void:
	# Match turn 3 is the first player's second turn.
	assert_eq(RuleChecker.legal_cells(_book.rule("R20"), _position(0, 3), 0, BallColour.RED).size(), 36)


func test_r20_on_the_first_players_third_turn_allows_only_the_edge() -> void:
	assert_eq(RuleChecker.legal_cells(_book.rule("R20"), _position(1, 5), 1, BallColour.RED).size(), EDGE_CELLS)


func test_r20_counts_the_second_players_turns_from_their_own_first_turn() -> void:
	# Match turns 2, 4 and 6 are the second player's 1st, 2nd and 3rd turns.
	var rule: Rule = _book.rule("R20")
	assert_eq(RuleChecker.legal_cells(rule, _position(0, 2), 1, BallColour.BLUE).size(), EDGE_CELLS, "1st turn")
	assert_eq(RuleChecker.legal_cells(rule, _position(0, 4), 1, BallColour.BLUE).size(), 36, "2nd turn")
	assert_eq(RuleChecker.legal_cells(rule, _position(1, 6), 0, BallColour.BLUE).size(), EDGE_CELLS, "3rd turn")


func test_r20_forbids_an_inner_cell_on_an_odd_turn_but_not_an_even_one() -> void:
	var position: MatchPosition = MatchPosition.new(Board.parse([
		"......",
		".b....",
		"..R...",
		"......",
		"......",
		"......",
	]), 0)
	var rule: Rule = _book.rule("R20")
	position.turn = 3
	assert_true(RuleChecker.is_legal(rule, position, 0, BallColour.GREEN, Vector2i(3, 3)), "2nd turn")
	position.turn = 5
	assert_false(RuleChecker.is_legal(rule, position, 0, BallColour.GREEN, Vector2i(3, 3)), "3rd turn")
	assert_true(RuleChecker.is_legal(rule, position, 0, BallColour.GREEN, Vector2i(0, 3)), "3rd turn, edge")


# R21 For your first 5 turns, only rows 3 and 4 -----------------------------
# Rows are numbered 1-6 from the first player's side: y 3 and 2 are rows 3
# and 4 when player 0 went first (row = 6 - y), y 2 and 3 when player 1 did.

func test_r21_on_the_holders_first_turn_allows_only_rows_3_and_4() -> void:
	var cells: Array[Vector2i] = RuleChecker.legal_cells(_book.rule("R21"), _position(0, 1), 0, BallColour.RED)
	assert_eq(cells.size(), 12)
	for cell: Vector2i in cells:
		assert_true([3, 4].has(Board.row_number(cell, 0)), str(cell))


func test_r21_restricts_the_first_players_turns_up_to_their_fifth() -> void:
	# Match turns 9 and 11 are the first player's 5th and 6th turns.
	var rule: Rule = _book.rule("R21")
	assert_eq(RuleChecker.legal_cells(rule, _position(0, 9), 0, BallColour.RED).size(), 12, "5th turn")
	assert_eq(RuleChecker.legal_cells(rule, _position(0, 11), 0, BallColour.RED).size(), 36, "6th turn")


func test_r21_restricts_the_second_players_turns_up_to_their_fifth() -> void:
	# Match turns 10 and 12 are the second player's 5th and 6th turns.
	var rule: Rule = _book.rule("R21")
	assert_eq(RuleChecker.legal_cells(rule, _position(1, 10), 0, BallColour.RED).size(), 12, "5th turn")
	assert_eq(RuleChecker.legal_cells(rule, _position(1, 12), 0, BallColour.RED).size(), 36, "6th turn")


func test_r21_reads_rows_3_and_4_the_same_for_both_first_players() -> void:
	var rule: Rule = _book.rule("R21")
	var player_0_first: MatchPosition = _position(0, 2)
	var player_1_first: MatchPosition = _position(1, 1)
	# Player 0 first: row 3 is y 3, row 4 is y 2, row 5 is y 1.
	assert_true(RuleChecker.is_legal(rule, player_0_first, 1, BallColour.BLUE, Vector2i(0, 3)), "row 3")
	assert_true(RuleChecker.is_legal(rule, player_0_first, 1, BallColour.BLUE, Vector2i(5, 2)), "row 4")
	assert_false(RuleChecker.is_legal(rule, player_0_first, 1, BallColour.BLUE, Vector2i(2, 1)), "row 5")
	assert_false(RuleChecker.is_legal(rule, player_0_first, 1, BallColour.BLUE, Vector2i(2, 5)), "row 1")
	# Player 1 first: row 3 is y 2, row 4 is y 3, row 2 is y 1.
	assert_true(RuleChecker.is_legal(rule, player_1_first, 1, BallColour.BLUE, Vector2i(0, 2)), "row 3")
	assert_true(RuleChecker.is_legal(rule, player_1_first, 1, BallColour.BLUE, Vector2i(5, 3)), "row 4")
	assert_false(RuleChecker.is_legal(rule, player_1_first, 1, BallColour.BLUE, Vector2i(2, 1)), "row 2")
	assert_false(RuleChecker.is_legal(rule, player_1_first, 1, BallColour.BLUE, Vector2i(2, 0)), "row 1")


func test_r21_with_rows_3_and_4_full_allows_no_cell_in_the_first_turns() -> void:
	var position: MatchPosition = MatchPosition.new(Board.parse([
		"......",
		"......",
		"YyBbRr",
		"GgYyBb",
		"......",
		"......",
	]), 0)
	position.turn = 7
	assert_eq(RuleChecker.legal_cells(_book.rule("R21"), position, 0, BallColour.GREEN).size(), 0)


# R22 After any skip, must touch one of your own balls ----------------------

func _skip_position(skips: Array[int]) -> MatchPosition:
	var position: MatchPosition = MatchPosition.new(Board.parse([
		"......",
		".R....",
		"......",
		"......",
		"....b.",
		"......",
	]), 0)
	position.turn = 7
	position.skips = skips
	return position


func test_r22_after_a_skip_allows_only_cells_next_to_the_holders_balls() -> void:
	var cells: Array[Vector2i] = RuleChecker.legal_cells(_book.rule("R22"), _skip_position([1, 0]), 0, BallColour.GREEN)
	var expected: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
		Vector2i(0, 1), Vector2i(2, 1),
		Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2),
	]
	expected.sort()
	cells.sort()
	assert_eq(cells, expected)


func test_r22_before_any_skip_allows_every_cell() -> void:
	assert_eq(RuleChecker.legal_cells(_book.rule("R22"), _skip_position([0, 0]), 0, BallColour.GREEN).size(), 34)


func test_r22_is_switched_on_by_the_opponents_skip_too() -> void:
	var position: MatchPosition = _skip_position([0, 1])
	var rule: Rule = _book.rule("R22")
	assert_true(RuleChecker.is_legal(rule, position, 0, BallColour.GREEN, Vector2i(2, 2)), "next to R")
	assert_false(RuleChecker.is_legal(rule, position, 0, BallColour.GREEN, Vector2i(3, 3)), "next to b only")
	assert_false(RuleChecker.is_legal(rule, position, 0, BallColour.GREEN, Vector2i(5, 5)), "next to b only")
	assert_true(RuleChecker.is_legal(rule, position, 1, BallColour.GREEN, Vector2i(3, 3)), "player 1, next to b")
	assert_false(RuleChecker.is_legal(rule, position, 1, BallColour.GREEN, Vector2i(2, 2)), "player 1, next to R only")


func test_r22_with_none_of_the_holders_balls_on_the_board_allows_every_cell() -> void:
	var position: MatchPosition = MatchPosition.new(Board.parse([
		"......",
		".r....",
		"......",
		"......",
		"....b.",
		"......",
	]), 1)
	position.turn = 2
	position.skips = [2, 1]
	assert_eq(RuleChecker.legal_cells(_book.rule("R22"), position, 0, BallColour.YELLOW).size(), 34)
