extends GutTest

# The rule checker seam: rule data + board + target, colour and holder
# -> legal / illegal, and the set of legal cells.

const INNER_CELLS: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1),
	Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
	Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3),
	Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4),
]

var _book: RuleBook


func before_each() -> void:
	_book = RuleBook.load_default()


func _position(rows: PackedStringArray) -> MatchPosition:
	return MatchPosition.from_board(Board.parse(rows))


func _empty_position() -> MatchPosition:
	return MatchPosition.from_board(Board.new())


func test_r04_legal_cells_on_an_empty_board_are_the_inner_cells() -> void:
	var cells: Array[Vector2i] = RuleChecker.legal_cells(_book.rule("R04"), _empty_position(), 0, BallColour.RED)
	assert_eq(_sorted(cells), _sorted(INNER_CELLS))


func test_r04_forbids_every_side_and_corner() -> void:
	var rule: Rule = _book.rule("R04")
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(5, 5), Vector2i(0, 3), Vector2i(5, 2), Vector2i(3, 0), Vector2i(2, 5)]:
		assert_false(RuleChecker.is_legal(rule, _empty_position(), 0, BallColour.BLUE, cell), "edge cell %s" % cell)


func test_r04_allows_an_inner_cell_for_either_holder() -> void:
	var rule: Rule = _book.rule("R04")
	assert_true(RuleChecker.is_legal(rule, _empty_position(), 0, BallColour.YELLOW, Vector2i(1, 4)))
	assert_true(RuleChecker.is_legal(rule, _empty_position(), 1, BallColour.GREEN, Vector2i(4, 1)))


func test_an_occupied_cell_is_never_legal() -> void:
	var position: MatchPosition = _position([
		"......",
		"......",
		"..R...",
		"......",
		"......",
		"......",
	])
	var rule: Rule = _book.rule("R04")
	assert_false(RuleChecker.is_legal(rule, position, 0, BallColour.RED, Vector2i(2, 2)))
	assert_false(RuleChecker.legal_cells(rule, position, 0, BallColour.RED).has(Vector2i(2, 2)))
	assert_eq(RuleChecker.legal_cells(rule, position, 0, BallColour.RED).size(), 15)


func test_r04_carries_its_player_text_and_data() -> void:
	var rule: Rule = _book.rule("R04")
	assert_eq(rule.text, "Never on the edge")
	assert_eq(rule.to_data(), {"id": "R04", "text": "Never on the edge", "template": "not_on_zone", "values": {"zone": "edge"}})


func test_a_rule_built_from_the_same_data_behaves_the_same() -> void:
	var copy: Rule = _book.make_rule(_book.rule("R04").to_data())
	assert_true(RuleChecker.is_legal(copy, _empty_position(), 0, BallColour.RED, Vector2i(2, 2)))
	assert_false(RuleChecker.is_legal(copy, _empty_position(), 0, BallColour.RED, Vector2i(0, 2)))


func test_rule_data_with_an_unknown_template_is_rejected() -> void:
	var rule: Rule = _book.make_rule({"id": "X", "text": "?", "template": "nope", "values": {}})
	assert_null(rule)
	assert_push_error("unknown template")


func test_rule_data_with_a_value_its_blank_does_not_allow_is_rejected() -> void:
	var rule: Rule = _book.make_rule({"id": "X", "text": "?", "template": "not_on_zone", "values": {"zone": "moon"}})
	assert_null(rule)
	assert_push_error("not allowed")


func test_rule_data_missing_a_blank_is_rejected() -> void:
	var rule: Rule = _book.make_rule({"id": "X", "text": "?", "template": "not_on_zone", "values": {}})
	assert_null(rule)
	assert_push_error("no value for blank")


func test_a_permissive_rule_defined_as_data_allows_every_empty_cell() -> void:
	_book.add_template("anywhere", {"blanks": {}, "tree": {"part": "all", "of": []}})
	var rule: Rule = _book.make_rule({"id": "T1", "text": "Anywhere", "template": "anywhere", "values": {}})
	var position: MatchPosition = _position([
		"Y.....",
		"......",
		"..r...",
		"......",
		"......",
		".....G",
	])
	assert_eq(RuleChecker.legal_cells(rule, position, 1, BallColour.RED).size(), 33)


func test_all_fails_when_any_of_its_conditions_fails() -> void:
	var off_edge: Dictionary = {"part": "count_at_most", "n": 0, "of": {"part": "in_zone", "zone": "edge", "of": {"part": "target"}}}
	_book.add_template("both", {"blanks": {}, "tree": {"part": "all", "of": [{"part": "all", "of": []}, off_edge]}})
	var rule: Rule = _book.make_rule({"id": "T2", "text": "Both", "template": "both", "values": {}})
	assert_true(RuleChecker.is_legal(rule, _empty_position(), 0, BallColour.RED, Vector2i(2, 2)))
	assert_false(RuleChecker.is_legal(rule, _empty_position(), 0, BallColour.RED, Vector2i(0, 2)))


# R01 Never next to the same colour --------------------------------------------

func test_r01_forbids_every_neighbour_of_a_ball_of_the_placed_colour() -> void:
	var position: MatchPosition = _position([
		"......",
		"......",
		"..r...",
		"......",
		"......",
		"......",
	])
	var cells: Array[Vector2i] = RuleChecker.legal_cells(_book.rule("R01"), position, 0, BallColour.RED)
	var forbidden: Array[Vector2i] = [
		Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
		Vector2i(1, 2), Vector2i(3, 2),
		Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3),
	]
	assert_eq(cells.size(), 27)
	for cell: Vector2i in forbidden:
		assert_false(cells.has(cell), "neighbour %s" % cell)


func test_r01_counts_the_holders_own_balls_too() -> void:
	var position: MatchPosition = _position([
		"......",
		"......",
		"......",
		"...B..",
		"......",
		"......",
	])
	var rule: Rule = _book.rule("R01")
	assert_false(RuleChecker.is_legal(rule, position, 0, BallColour.BLUE, Vector2i(4, 4)), "diagonal, own ball")
	assert_false(RuleChecker.is_legal(rule, position, 1, BallColour.BLUE, Vector2i(3, 2)), "orthogonal, opponent ball")
	assert_true(RuleChecker.is_legal(rule, position, 0, BallColour.BLUE, Vector2i(5, 3)), "two cells away")


func test_r01_allows_a_cell_next_to_other_colours_only() -> void:
	var position: MatchPosition = _position([
		"......",
		".Yr...",
		".g.B..",
		".Rb...",
		"......",
		"......",
	])
	var rule: Rule = _book.rule("R01")
	assert_true(RuleChecker.is_legal(rule, position, 0, BallColour.GREEN, Vector2i(3, 1)), "next to red and blue")
	assert_true(RuleChecker.is_legal(rule, position, 1, BallColour.RED, Vector2i(0, 0)), "next to yellow")
	assert_false(RuleChecker.is_legal(rule, position, 0, BallColour.YELLOW, Vector2i(2, 2)))
	assert_false(RuleChecker.is_legal(rule, position, 1, BallColour.GREEN, Vector2i(2, 2)))


func test_r01_in_a_corner_looks_at_the_three_neighbours_on_the_board() -> void:
	var position: MatchPosition = _position([
		"......",
		"......",
		"......",
		"......",
		"....g.",
		"......",
	])
	var rule: Rule = _book.rule("R01")
	assert_false(RuleChecker.is_legal(rule, position, 0, BallColour.GREEN, Vector2i(5, 5)), "diagonal into the corner")
	assert_true(RuleChecker.is_legal(rule, position, 0, BallColour.GREEN, Vector2i(0, 0)))
	assert_true(RuleChecker.is_legal(rule, position, 0, BallColour.RED, Vector2i(5, 5)))


func test_r01_allows_every_cell_with_no_ball_of_the_colour_on_the_board() -> void:
	assert_eq(RuleChecker.legal_cells(_book.rule("R01"), _empty_position(), 1, BallColour.YELLOW).size(), 36)


func test_r01_carries_its_player_text() -> void:
	assert_eq(_book.rule("R01").text, "Never next to the same colour")


# R07 Never next to an opponent ball -------------------------------------------

func test_r07_forbids_every_neighbour_of_an_opponent_ball_whatever_its_colour() -> void:
	var position: MatchPosition = _position([
		"......",
		"......",
		"......",
		"......",
		"...g..",
		"......",
	])
	var cells: Array[Vector2i] = RuleChecker.legal_cells(_book.rule("R07"), position, 0, BallColour.RED)
	var forbidden: Array[Vector2i] = [
		Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3),
		Vector2i(2, 4), Vector2i(4, 4),
		Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5),
	]
	assert_eq(cells.size(), 27)
	for cell: Vector2i in forbidden:
		assert_false(cells.has(cell), "neighbour %s" % cell)


func test_r07_ignores_the_holders_own_balls() -> void:
	var position: MatchPosition = _position([
		"r.....",
		"......",
		"..YB..",
		"..GR..",
		"......",
		"......",
	])
	var rule: Rule = _book.rule("R07")
	assert_true(RuleChecker.is_legal(rule, position, 0, BallColour.RED, Vector2i(4, 4)), "diagonal to own red")
	assert_true(RuleChecker.is_legal(rule, position, 0, BallColour.BLUE, Vector2i(1, 2)), "next to own yellow")
	assert_false(RuleChecker.is_legal(rule, position, 0, BallColour.BLUE, Vector2i(1, 1)), "diagonal to opponent red in the corner")
	assert_false(RuleChecker.is_legal(rule, position, 0, BallColour.YELLOW, Vector2i(0, 1)), "below opponent red on the edge")


func test_r07_for_player_1_avoids_player_0_balls() -> void:
	var position: MatchPosition = _position([
		"......",
		"......",
		"......",
		"......",
		"....b.",
		"Y.....",
	])
	var rule: Rule = _book.rule("R07")
	assert_false(RuleChecker.is_legal(rule, position, 1, BallColour.GREEN, Vector2i(1, 4)), "diagonal to opponent yellow")
	assert_false(RuleChecker.is_legal(rule, position, 1, BallColour.GREEN, Vector2i(1, 5)))
	assert_true(RuleChecker.is_legal(rule, position, 1, BallColour.GREEN, Vector2i(5, 5)), "next to own blue")
	assert_eq(RuleChecker.legal_cells(rule, position, 1, BallColour.GREEN).size(), 31)


func test_r07_allows_every_empty_cell_with_no_opponent_balls() -> void:
	var position: MatchPosition = _position([
		"......",
		".rr...",
		"......",
		"...g..",
		"......",
		"......",
	])
	assert_eq(RuleChecker.legal_cells(_book.rule("R07"), position, 1, BallColour.RED).size(), 33)


func test_r07_carries_its_player_text() -> void:
	assert_eq(_book.rule("R07").text, "Never next to an opponent ball")


# R18 Only cells with 2+ empty neighbours ---------------------------------------

func test_r18_forbids_a_corner_with_one_empty_neighbour() -> void:
	var position: MatchPosition = _position([
		".Y....",
		"r.....",
		"......",
		"......",
		"......",
		"......",
	])
	assert_false(RuleChecker.is_legal(_book.rule("R18"), position, 0, BallColour.RED, Vector2i(0, 0)))


func test_r18_allows_a_corner_with_exactly_two_empty_neighbours() -> void:
	var position: MatchPosition = _position([
		"......",
		"......",
		"......",
		"......",
		"....b.",
		"......",
	])
	assert_true(RuleChecker.is_legal(_book.rule("R18"), position, 1, BallColour.BLUE, Vector2i(5, 5)))


func test_r18_counts_diagonal_neighbours_as_filled() -> void:
	var position: MatchPosition = _position([
		".B....",
		".g....",
		"......",
		"......",
		"....G.",
		"....r.",
	])
	var rule: Rule = _book.rule("R18")
	assert_false(RuleChecker.is_legal(rule, position, 0, BallColour.YELLOW, Vector2i(0, 0)), "corner, one side and its diagonal filled")
	assert_false(RuleChecker.is_legal(rule, position, 0, BallColour.YELLOW, Vector2i(5, 5)), "corner, its diagonal and one side filled")
	assert_true(RuleChecker.is_legal(rule, position, 0, BallColour.YELLOW, Vector2i(0, 1)), "edge, three of five empty")


func test_r18_counts_only_empty_neighbours_of_an_inner_cell() -> void:
	var seven_filled: MatchPosition = _position([
		"......",
		".yRb..",
		".G.Y..",
		".rB...",
		"......",
		"......",
	])
	var six_filled: MatchPosition = _position([
		"......",
		".yRb..",
		".G.Y..",
		".r....",
		"......",
		"......",
	])
	var rule: Rule = _book.rule("R18")
	assert_false(RuleChecker.is_legal(rule, seven_filled, 0, BallColour.GREEN, Vector2i(2, 2)))
	assert_true(RuleChecker.is_legal(rule, six_filled, 0, BallColour.GREEN, Vector2i(2, 2)))


func test_r18_allows_every_cell_of_an_empty_board() -> void:
	assert_eq(RuleChecker.legal_cells(_book.rule("R18"), _empty_position(), 0, BallColour.RED).size(), 36)


func test_r18_carries_its_player_text() -> void:
	assert_eq(_book.rule("R18").text, "Only cells with 2+ empty neighbours")


func test_the_empty_neighbour_count_is_1_to_8() -> void:
	# Numbers in rule data are floats, as JSON gives them.
	for n: float in [1.0, 8.0]:
		var rule: Rule = _book.make_rule({"id": "X", "text": "?", "template": "min_empty_neighbours", "values": {"n": n}})
		assert_not_null(rule, "n = %s" % n)
	for n: float in [0.0, 9.0]:
		var rule: Rule = _book.make_rule({"id": "X", "text": "?", "template": "min_empty_neighbours", "values": {"n": n}})
		assert_null(rule, "n = %s" % n)
		assert_push_error("not allowed")


func _sorted(cells: Array[Vector2i]) -> Array[Vector2i]:
	var copy: Array[Vector2i] = cells.duplicate()
	copy.sort()
	return copy
