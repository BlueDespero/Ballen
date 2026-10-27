extends GutTest

# Colour and count rules (R02, R06) through the rule checker seam.
# Board.parse: upper case = player 0, lower case = player 1.

var _book: RuleBook


func before_each() -> void:
	_book = RuleBook.load_default()


func _position(rows: PackedStringArray) -> MatchPosition:
	return MatchPosition.new(Board.parse(rows))


# R02 Red only next to blue --------------------------------------------------

func test_r02_allows_red_only_next_to_a_blue_ball_of_either_owner() -> void:
	var position: MatchPosition = _position([
		"B.....",
		"......",
		"......",
		"......",
		"....b.",
		"......",
	])
	var cells: Array[Vector2i] = RuleChecker.legal_cells(_book.rule("R02"), position, 0, BallColour.RED)
	var expected: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1),
		Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3),
		Vector2i(3, 4), Vector2i(5, 4),
		Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5),
	]
	expected.sort()
	cells.sort()
	assert_eq(cells, expected)


func test_r02_is_not_met_by_other_colours_next_to_the_target() -> void:
	var position: MatchPosition = _position([
		"......",
		"......",
		"..YRG.",
		"..y.g.",
		"......",
		".....B",
	])
	assert_false(RuleChecker.is_legal(_book.rule("R02"), position, 1, BallColour.RED, Vector2i(3, 3)))


func test_r02_leaves_the_other_colours_unrestricted() -> void:
	var position: MatchPosition = _position([
		"B.....",
		"......",
		"......",
		"......",
		"......",
		"......",
	])
	var rule: Rule = _book.rule("R02")
	for colour: String in [BallColour.YELLOW, BallColour.BLUE, BallColour.GREEN]:
		assert_eq(RuleChecker.legal_cells(rule, position, 0, colour).size(), 35, colour)


func test_r02_with_no_blue_ball_to_touch_allows_red_on_every_cell() -> void:
	var position: MatchPosition = _position([
		"R.....",
		"..y...",
		"......",
		"...g..",
		"......",
		".....r",
	])
	assert_eq(RuleChecker.legal_cells(_book.rule("R02"), position, 0, BallColour.RED).size(), 32)


func test_r02_on_an_empty_board_allows_red_on_every_cell() -> void:
	var position: MatchPosition = MatchPosition.new(Board.new())
	assert_eq(RuleChecker.legal_cells(_book.rule("R02"), position, 1, BallColour.RED).size(), 36)


func test_r02_carries_its_player_text_and_data() -> void:
	var rule: Rule = _book.rule("R02")
	assert_eq(rule.text, "Red only next to blue")
	assert_eq(rule.to_data(), {"id": "R02", "text": "Red only next to blue", "template": "colour_only_next_to",
		"values": {"colour": "red", "other": "blue"}})
