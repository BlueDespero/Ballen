extends GutTest

# The match seam: send commands, check phase, history and PublicView.

const Fixtures := preload("res://test/helpers/fixtures.gd")

var _book: RuleBook


func before_each() -> void:
	_book = Fixtures.book()


func _r04_match(seed_value: int) -> Match:
	var r04: Rule = _book.rule("R04")
	return Fixtures.new_match(_book, r04, r04, seed_value)


## A match past the first colour pick: the first player is to place red.
func _started(current_match: Match) -> Match:
	current_match.submit(Players.opponent(current_match.first_player()), Command.pick_colour(BallColour.RED))
	return current_match


func test_the_coin_toss_follows_the_seeded_rng() -> void:
	assert_eq(_r04_match(7).first_player(), _r04_match(7).first_player())
	var firsts: Array[int] = []
	for seed_value: int in 20:
		var first: int = _r04_match(seed_value).first_player()
		if not firsts.has(first):
			firsts.append(first)
	firsts.sort()
	assert_eq(firsts, [0, 1] as Array[int], "both players win the toss over 20 seeds")


func test_a_true_rule_outside_its_deck_is_rejected() -> void:
	var r04: Rule = _book.rule("R04")
	var decks: Array[Deck] = [Fixtures.deck_with(_book, r04, "A"), Fixtures.deck_with(_book, r04, "B")]
	var true_rules: Array[Rule] = [r04, Fixtures.anywhere(_book, "Z")]
	assert_null(Match.create(decks, true_rules, Fixtures.rng(1)))
	assert_push_error("not in their deck")


func test_a_deck_of_other_than_five_rules_is_rejected() -> void:
	var r04: Rule = _book.rule("R04")
	var short: Array[Rule] = [r04, Fixtures.anywhere(_book, "A1")]
	var decks: Array[Deck] = [Deck.new(short), Fixtures.deck_with(_book, r04, "B")]
	var true_rules: Array[Rule] = [r04, r04]
	assert_null(Match.create(decks, true_rules, Fixtures.rng(1)))
	assert_push_error("has 2 rules")


func test_a_new_match_waits_for_the_second_player_to_pick_the_first_colour() -> void:
	var current_match: Match = _r04_match(1)
	var second: int = Players.opponent(current_match.first_player())
	assert_eq(current_match.phase(), Match.Phase.FIRST_COLOUR)
	assert_eq(current_match.awaiting_players(), [second] as Array[int])


func test_the_first_player_cannot_pick_the_first_colour() -> void:
	var current_match: Match = _r04_match(1)
	assert_false(current_match.submit(current_match.first_player(), Command.pick_colour(BallColour.RED)))
	assert_eq(current_match.phase(), Match.Phase.FIRST_COLOUR)
	assert_eq(current_match.history().size(), 0)


func test_the_first_colour_pick_starts_the_first_players_turn_in_that_colour() -> void:
	var current_match: Match = _r04_match(1)
	var first: int = current_match.first_player()
	assert_true(current_match.submit(Players.opponent(first), Command.pick_colour(BallColour.GREEN)))
	assert_eq(current_match.phase(), Match.Phase.PLACE)
	assert_eq(current_match.current_player(), first)
	assert_eq(current_match.current_colour(), BallColour.GREEN)
	assert_eq(current_match.turn(), 1)


func test_history_records_the_first_colour_pick() -> void:
	var current_match: Match = _r04_match(1)
	var second: int = Players.opponent(current_match.first_player())
	current_match.submit(second, Command.pick_colour(BallColour.BLUE))
	var history: Array[HistoryEntry] = current_match.history()
	assert_eq(history.size(), 1)
	assert_eq(history[0].type, HistoryEntry.Type.COLOUR_PICK)
	assert_eq(history[0].player, second)
	assert_eq(history[0].colour, BallColour.BLUE)


func test_an_unknown_colour_is_rejected() -> void:
	var current_match: Match = _r04_match(1)
	assert_false(current_match.submit(Players.opponent(current_match.first_player()), Command.pick_colour("purple")))
	assert_eq(current_match.phase(), Match.Phase.FIRST_COLOUR)


func test_a_placement_before_the_first_colour_pick_is_rejected() -> void:
	var current_match: Match = _r04_match(1)
	assert_false(current_match.submit(current_match.first_player(), Command.place(Vector2i(2, 2))))
	assert_false(current_match.submit(Players.opponent(current_match.first_player()), Command.place(Vector2i(2, 2))))
	assert_eq(current_match.history().size(), 0)


func test_the_current_player_places_on_a_legal_cell() -> void:
	var current_match: Match = _started(_r04_match(1))
	var first: int = current_match.first_player()
	assert_true(current_match.submit(first, Command.place(Vector2i(2, 3))))
	assert_eq(current_match.phase(), Match.Phase.PICK_COLOUR)
	var last: HistoryEntry = current_match.history().back()
	assert_eq(last.type, HistoryEntry.Type.PLACEMENT)
	assert_eq(last.player, first)
	assert_eq(last.cell, Vector2i(2, 3))
	assert_eq(last.colour, BallColour.RED)


func test_a_placement_on_a_cell_the_true_rule_forbids_is_rejected() -> void:
	var current_match: Match = _started(_r04_match(1))
	assert_false(current_match.submit(current_match.first_player(), Command.place(Vector2i(0, 3))))
	assert_false(current_match.submit(current_match.first_player(), Command.place(Vector2i(9, 9))))
	assert_eq(current_match.phase(), Match.Phase.PLACE)
	assert_eq(current_match.history().size(), 1)


func test_the_opponent_cannot_place_on_the_current_players_turn() -> void:
	var current_match: Match = _started(_r04_match(1))
	assert_false(current_match.submit(Players.opponent(current_match.first_player()), Command.place(Vector2i(2, 3))))
	assert_eq(current_match.phase(), Match.Phase.PLACE)


func test_a_second_placement_in_the_same_turn_is_rejected() -> void:
	var current_match: Match = _started(_r04_match(1))
	current_match.submit(current_match.first_player(), Command.place(Vector2i(2, 3)))
	assert_false(current_match.submit(current_match.first_player(), Command.place(Vector2i(3, 3))))
	assert_eq(current_match.history().size(), 2)


func test_the_match_lists_the_current_players_legal_cells() -> void:
	var current_match: Match = _started(_r04_match(1))
	assert_eq(current_match.legal_cells().size(), 16)
	assert_true(current_match.is_legal(Vector2i(1, 1)))
	assert_false(current_match.is_legal(Vector2i(0, 0)))
	current_match.submit(current_match.first_player(), Command.place(Vector2i(1, 1)))
	assert_eq(current_match.legal_cells().size(), 0, "no legal cells outside the PLACE phase")

func test_picking_a_colour_after_placing_ends_the_turn() -> void:
	var current_match: Match = _started(_r04_match(1))
	var first: int = current_match.first_player()
	var second: int = Players.opponent(first)
	current_match.submit(first, Command.place(Vector2i(2, 3)))
	assert_true(current_match.submit(first, Command.pick_colour(BallColour.YELLOW)))
	assert_eq(current_match.phase(), Match.Phase.PLACE)
	assert_eq(current_match.turn(), 2)
	assert_eq(current_match.current_player(), second)
	assert_eq(current_match.current_colour(), BallColour.YELLOW)
	assert_eq(current_match.awaiting_players(), [second] as Array[int])


func test_a_colour_pick_before_placing_is_rejected() -> void:
	var current_match: Match = _started(_r04_match(1))
	assert_false(current_match.submit(current_match.first_player(), Command.pick_colour(BallColour.BLUE)))
	assert_eq(current_match.phase(), Match.Phase.PLACE)
	assert_eq(current_match.turn(), 1)


func test_the_opponent_cannot_pick_the_colour_on_the_current_players_turn() -> void:
	var current_match: Match = _started(_r04_match(1))
	current_match.submit(current_match.first_player(), Command.place(Vector2i(2, 3)))
	assert_false(current_match.submit(Players.opponent(current_match.first_player()), Command.pick_colour(BallColour.BLUE)))
	assert_eq(current_match.phase(), Match.Phase.PICK_COLOUR)


func test_turns_alternate_and_history_keeps_every_event_in_order() -> void:
	var current_match: Match = _started(_r04_match(1))
	var first: int = current_match.first_player()
	var second: int = Players.opponent(first)
	current_match.submit(first, Command.place(Vector2i(1, 1)))
	current_match.submit(first, Command.pick_colour(BallColour.GREEN))
	assert_false(current_match.submit(second, Command.place(Vector2i(1, 1))), "occupied cell")
	current_match.submit(second, Command.place(Vector2i(2, 2)))
	current_match.submit(second, Command.pick_colour(BallColour.GREEN))
	current_match.submit(first, Command.place(Vector2i(3, 3)))
	var lines: Array[String] = []
	for entry: HistoryEntry in current_match.history():
		lines.append(str(entry))
	assert_eq(lines, [
		"player %d picks red" % second,
		"player %d places red at (1, 1)" % first,
		"player %d picks green" % first,
		"player %d places green at (2, 2)" % second,
		"player %d picks green" % second,
		"player %d places green at (3, 3)" % first,
	] as Array[String])
	assert_eq(current_match.turn(), 3)
	assert_eq(current_match.current_player(), first)

func _from_position(position: MatchPosition) -> Match:
	var r04: Rule = _book.rule("R04")
	var decks: Array[Deck] = [Fixtures.deck_with(_book, r04, "A"), Fixtures.deck_with(_book, r04, "B")]
	var true_rules: Array[Rule] = [r04, r04]
	return Match.from_position(position, decks, true_rules, Fixtures.rng(1))


func _late_position() -> MatchPosition:
	var position: MatchPosition = MatchPosition.new(Board.parse([
		"......",
		".R....",
		"..b...",
		"......",
		"......",
		"......",
	]), 1)
	position.turn = 5
	position.colour = BallColour.BLUE
	position.skips = [2, 1]
	position.history = [
		HistoryEntry.colour_pick(0, BallColour.RED),
		HistoryEntry.placement(1, Vector2i(2, 2), BallColour.BLUE),
	]
	return position


func test_a_match_starts_from_a_given_position() -> void:
	var current_match: Match = _from_position(_late_position())
	assert_eq(current_match.phase(), Match.Phase.PLACE)
	assert_eq(current_match.turn(), 5)
	assert_eq(current_match.first_player(), 1)
	assert_eq(current_match.current_player(), 1, "odd turns belong to the first player")
	assert_eq(current_match.current_colour(), BallColour.BLUE)
	assert_eq(current_match.skip_count(0), 2)
	assert_eq(current_match.skip_count(1), 1)
	assert_eq(current_match.history().size(), 2)
	assert_eq(current_match.legal_cells().size(), 14, "16 inner cells minus 2 occupied")
	assert_false(current_match.submit(1, Command.place(Vector2i(1, 1))))
	assert_true(current_match.submit(1, Command.place(Vector2i(4, 4))))
	assert_eq(current_match.history().size(), 3)


func test_a_match_from_a_position_is_not_changed_by_later_edits_to_that_position() -> void:
	var position: MatchPosition = _late_position()
	var current_match: Match = _from_position(position)
	position.board.place(Vector2i(4, 4), Ball.new(BallColour.RED, 0))
	position.history.clear()
	position.skips[0] = 0
	assert_true(current_match.is_legal(Vector2i(4, 4)))
	assert_eq(current_match.history().size(), 2)
	assert_eq(current_match.skip_count(0), 2)


func test_a_position_before_the_first_colour_pick_waits_for_it() -> void:
	var current_match: Match = _from_position(MatchPosition.new(Board.new(), 0))
	assert_eq(current_match.phase(), Match.Phase.FIRST_COLOUR)
	assert_eq(current_match.awaiting_players(), [1] as Array[int])


## R04 for both: the 16 inner cells are all the legal cells there are. Here
## only (4, 4) is free, and player 1 (second) is to place blue on it, so the
## next turn, player 0's, starts with no legal cell.
func _one_inner_cell_left(skips: Array[int]) -> MatchPosition:
	var position: MatchPosition = MatchPosition.new(Board.parse([
		"......",
		".RbRb.",
		".bRbR.",
		".RbRb.",
		".bRb..",
		"......",
	]), 0)
	position.turn = 16
	position.colour = BallColour.BLUE
	position.skips = skips
	return position


## Player 1 fills the last inner cell and hands player 0 red.
func _fill_the_last_inner_cell(current_match: Match) -> void:
	assert_true(current_match.submit(1, Command.place(Vector2i(4, 4))))
	assert_true(current_match.submit(1, Command.pick_colour(BallColour.RED)))


func test_a_player_with_no_legal_cell_skips_as_their_turn_starts() -> void:
	var current_match: Match = _from_position(_one_inner_cell_left([0, 0]))
	_fill_the_last_inner_cell(current_match)
	assert_eq(current_match.turn(), 17)
	assert_eq(current_match.current_player(), 0)
	assert_eq(current_match.skip_count(0), 1)
	assert_eq(current_match.skip_count(1), 0)
	var last: HistoryEntry = current_match.history().back()
	assert_eq(last.type, HistoryEntry.Type.SKIP)
	assert_eq(last.player, 0)
	assert_eq(last.colour, BallColour.RED, "history records the skipped colour")
	assert_eq(str(last), "player 0 skips red")
	assert_eq(current_match.public_view(0).position.board.empty_cells().size(), 20, "the skipped ball is not placed")


func test_after_a_skip_the_turn_goes_on_to_the_colour_pick() -> void:
	var current_match: Match = _from_position(_one_inner_cell_left([0, 0]))
	_fill_the_last_inner_cell(current_match)
	assert_eq(current_match.phase(), Match.Phase.PICK_COLOUR)
	assert_eq(current_match.awaiting_players(), [0] as Array[int])
	assert_false(current_match.submit(0, Command.place(Vector2i(0, 0))), "nothing to place")
	assert_true(current_match.submit(0, Command.pick_colour(BallColour.GREEN)))
	assert_eq(current_match.turn(), 18)
	assert_eq(current_match.skip_count(1), 1, "player 1 has no legal cell either")
	assert_eq(str(current_match.history().back()), "player 1 skips green")
	assert_eq(current_match.awaiting_players(), [1] as Array[int])


func test_a_match_from_a_position_with_no_legal_cell_starts_with_the_skip() -> void:
	var position: MatchPosition = _one_inner_cell_left([1, 0])
	position.board.place(Vector2i(4, 4), Ball.new(BallColour.BLUE, 1))
	position.turn = 17
	position.colour = BallColour.YELLOW
	var current_match: Match = _from_position(position)
	assert_eq(current_match.phase(), Match.Phase.PICK_COLOUR)
	assert_eq(current_match.skip_count(0), 2)
	assert_eq(str(current_match.history().back()), "player 0 skips yellow")


func test_the_third_skip_loses_the_match_at_once() -> void:
	var current_match: Match = _from_position(_one_inner_cell_left([2, 0]))
	_fill_the_last_inner_cell(current_match)
	assert_eq(current_match.skip_count(0), 3)
	assert_eq(str(current_match.history().back()), "player 0 skips red")
	assert_eq(current_match.phase(), Match.Phase.OVER)
	var result: MatchResult = current_match.result()
	assert_eq(result.winner, 1)
	assert_eq(result.reason, MatchResult.Reason.THIRD_SKIP)
	assert_eq(current_match.public_view(1).result.winner, 1, "both players see the result")
	assert_eq(current_match.awaiting_players(), [] as Array[int], "no guess, no colour pick")
	assert_false(current_match.submit(0, Command.pick_colour(BallColour.GREEN)))
	assert_eq(current_match.history().size(), 3)