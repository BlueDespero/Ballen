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


func _sorted(cells: Array[Vector2i]) -> Array[Vector2i]:
	var copy: Array[Vector2i] = cells.duplicate()
	copy.sort()
	return copy
