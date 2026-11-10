extends GutTest

# The compiled (bit-mask) rules allow exactly the cells the Parts interpreter
# allows: every built-in rule, and test trees using each part in other ways,
# on random boards and on positions from played matches, every colour, both
# holders.

## Trees the built-in rules don't use, so every part is checked in more than
## the one shape its template gives it.
const EXTRA_TREES: Array[Dictionary] = [
	{"part": "count_at_least", "n": 2, "of": {"part": "my_ball", "of": {"part": "within_distance", "n": 2, "of": {"part": "target"}}}},
	{"part": "count_at_most", "n": 1, "of": {"part": "any_ball", "of": {"part": "neighbours", "of": {"part": "target"}}}},
	{"part": "count_at_least", "n": 3, "of": {"part": "empty", "of": {"part": "neighbours", "of": {"part": "target"}}}},
	{"part": "count_at_least", "n": 1, "of": {"part": "in_rows", "from": 2, "to": 3, "of": {"part": "target"}}},
	{"part": "count_at_most", "n": 0, "of": {"part": "with_parity", "axis": "row", "parity": "odd", "of": {"part": "target"}}},
	{"part": "count_at_most", "n": 2, "of": {"part": "same_colour", "of": {"part": "in_zone", "zone": "edge", "of": {"part": "whole_board"}}}},
	{"part": "count_at_least", "n": 20, "of": {"part": "empty", "of": {"part": "other_cells", "of": {"part": "target"}}}},
	{"part": "count_at_least", "n": 1, "of": {"part": "opponent_ball", "of": {"part": "same_axis", "axis": "row", "of": {"part": "target"}}}},
	{"part": "no_more_than", "of": {"part": "my_ball", "of": {"part": "whole_board"}}, "than": {"part": "opponent_ball", "of": {"part": "whole_board"}}},
	{"part": "count_at_least", "n": 1, "of": {"part": "in_row_relative", "direction": "lower", "than": {"part": "opponent_last_ball", "of": {"part": "whole_board"}}, "of": {"part": "target"}}},
	{"part": "no_group_of", "n": 2, "of": {"part": "lines_through", "of": {"part": "target"}}},
	{"part": "no_group_of", "n": 4, "of": {"part": "lines_through", "of": {"part": "target"}}},
	{"part": "all", "of": []},
	{"part": "any", "of": []},
	{"part": "count_at_most", "n": 0, "of": {"part": "of_colour", "colour": "green", "of": {"part": "target"}}},
	{"part": "if_then", "if": {"part": "own_turn_at_most", "n": 2}, "then": {"part": "count_at_least", "n": 1, "of": {"part": "next_colour", "of": {"part": "neighbours", "of": {"part": "target"}}}}},
	{"part": "count_at_least", "n": 7, "of": {"part": "any_ball", "of": {"part": "whole_board"}}},
	{"part": "count_at_most", "n": 1, "of": {"part": "next_colour", "of": {"part": "within_distance", "n": 1, "of": {"part": "target"}}}},
	{"part": "count_at_least", "n": 2, "of": {"part": "in_zone", "zone": "edge", "of": {"part": "same_axis", "axis": "row", "of": {"part": "target"}}}},
	{"part": "if_then", "if": {"part": "skips_at_least", "n": 1}, "then": {"part": "count_at_least", "n": 1, "of": {"part": "with_parity", "axis": "row", "parity": "even", "of": {"part": "target"}}}},
]

var _book: RuleBook


func before_each() -> void:
	_book = RuleBook.load_default()


func _rules() -> Array[Rule]:
	var rules: Array[Rule] = []
	for rule_id: String in _book.rule_ids():
		rules.append(_book.rule(rule_id))
	for i: int in EXTRA_TREES.size():
		rules.append(Rule.new("T%d" % i, "test", "test", {}, EXTRA_TREES[i]))
	return rules


func _random_positions() -> Array[MatchPosition]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	var positions: Array[MatchPosition] = []
	for i: int in 8:
		var board: Board = Board.new()
		for cell: Vector2i in Board.all_cells():
			if rng.randf() < 0.15 + 0.08 * i:
				board.place(cell, Ball.new(BallColour.ALL[rng.randi_range(0, 3)], rng.randi_range(0, 1)))
		var position: MatchPosition = MatchPosition.new(board, rng.randi_range(0, 1))
		position.turn = rng.randi_range(1, 20)
		position.skips = [rng.randi_range(0, 2), rng.randi_range(0, 2)] as Array[int]
		positions.append(position)
	return positions


func _played_positions() -> Array[MatchPosition]:
	var positions: Array[MatchPosition] = []
	for seed_value: int in 3:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 100 + seed_value
		var decks: Array[Deck] = [Deck.draw(_book, rng), Deck.draw(_book, rng)]
		var played: Match = Match.create(decks, [decks[0].rules[0], decks[1].rules[0]] as Array[Rule], rng)
		var ais: Array[AIController] = [AIController.new(rng, GuessPolicy.new(INF)), AIController.new(rng, GuessPolicy.new(INF))]
		var commands: int = 0
		while played.phase() != Match.Phase.OVER and commands < 200:
			for player: int in played.awaiting_players():
				assert_true(played.submit(player, ais[player].decide(played.public_view(player))))
				commands += 1
				if commands % 3 == 0:
					positions.append(played.public_view(0).position)
	return positions


func test_every_built_in_rule_and_test_tree_compiles() -> void:
	for rule: Rule in _rules():
		assert_not_null(rule.compiled(), rule.id)


func test_compiled_rules_allow_exactly_the_interpreted_cells() -> void:
	var positions: Array[MatchPosition] = _random_positions()
	positions.append_array(_played_positions())
	assert_gt(positions.size(), 30)
	var mismatches: int = 0
	for position: MatchPosition in positions:
		for rule: Rule in _rules():
			for holder: int in Players.COUNT:
				for colour: String in BallColour.ALL:
					var compiled: int = rule.compiled().legal_mask(position, holder, colour)
					var interpreted: int = RuleChecker.interpreted_legal_mask(rule, position, holder, colour)
					if compiled != interpreted and mismatches < 10:
						mismatches += 1
						assert_eq(Board.cells_of(compiled), Board.cells_of(interpreted),
							"%s %s holder %d turn %d" % [rule.id, colour, holder, position.turn])
	assert_eq(mismatches, 0)


func test_a_tree_the_compiler_does_not_support_is_interpreted() -> void:
	var tree: Dictionary = {"part": "count_at_least", "n": 1, "of": {"part": "neighbours", "of": {"part": "whole_board"}}}
	var rule: Rule = Rule.new("U", "unsupported", "test", {}, tree)
	assert_null(rule.compiled())
	var position: MatchPosition = MatchPosition.new(Board.new())
	assert_eq(RuleChecker.legal_mask(rule, position, 0, BallColour.RED),
		RuleChecker.interpreted_legal_mask(rule, position, 0, BallColour.RED))
