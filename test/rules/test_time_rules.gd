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
