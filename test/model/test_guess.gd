extends GutTest

# The match seam for guesses: a player names one of the opponent's deck rules
# at the start of their turn or after placing, until they pick a colour.

const Fixtures := preload("res://test/helpers/fixtures.gd")

var _book: RuleBook


func before_each() -> void:
	_book = Fixtures.book()


## A match whose true rules are "AT" (player 0) and "BT" (player 1), each the
## first rule of a deck filled with A1..A4 / B1..B4; every rule allows every
## empty cell. Past the first colour pick: the first player is to place red.
func _started(seed_value: int) -> Match:
	var current_match: Match = Fixtures.new_match(_book, Fixtures.anywhere(_book, "AT"), Fixtures.anywhere(_book, "BT"), seed_value)
	current_match.submit(Players.opponent(current_match.first_player()), Command.pick_colour(BallColour.RED))
	return current_match


## The id of the true rule in this player's deck.
func _true_id(player: int) -> String:
	return "AT" if player == 0 else "BT"


## The id of a fake rule in this player's deck.
func _fake_id(player: int) -> String:
	return "A2" if player == 0 else "B2"


func test_a_right_guess_at_the_start_of_the_turn_wins() -> void:
	var current_match: Match = _started(1)
	var guesser: int = current_match.first_player()
	assert_true(current_match.submit(guesser, Command.guess(_true_id(Players.opponent(guesser)))))
	assert_eq(current_match.phase(), Match.Phase.OVER)
	assert_eq(current_match.result().winner, guesser)
	assert_eq(current_match.result().reason, MatchResult.Reason.RIGHT_GUESS)
	assert_eq(current_match.awaiting_players(), [] as Array[int])


func test_a_wrong_guess_at_the_start_of_the_turn_loses() -> void:
	var current_match: Match = _started(1)
	var guesser: int = current_match.first_player()
	var opponent: int = Players.opponent(guesser)
	assert_true(current_match.submit(guesser, Command.guess(_fake_id(opponent))))
	assert_eq(current_match.phase(), Match.Phase.OVER)
	assert_eq(current_match.result().winner, opponent)
	assert_eq(current_match.result().reason, MatchResult.Reason.WRONG_GUESS)


func test_history_records_a_right_guess() -> void:
	var current_match: Match = _started(1)
	var guesser: int = current_match.first_player()
	current_match.submit(guesser, Command.guess(_true_id(Players.opponent(guesser))))
	var last: HistoryEntry = current_match.history().back()
	assert_eq(last.type, HistoryEntry.Type.GUESS)
	assert_eq(last.player, guesser)
	assert_eq(last.rule_id, _true_id(Players.opponent(guesser)))
	assert_true(last.right)
	assert_eq(str(last), "player %d guesses %s, right" % [guesser, last.rule_id])


func test_history_records_a_wrong_guess() -> void:
	var current_match: Match = _started(1)
	var guesser: int = current_match.first_player()
	current_match.submit(guesser, Command.guess(_fake_id(Players.opponent(guesser))))
	var last: HistoryEntry = current_match.history().back()
	assert_eq(last.type, HistoryEntry.Type.GUESS)
	assert_eq(last.player, guesser)
	assert_eq(last.rule_id, _fake_id(Players.opponent(guesser)))
	assert_false(last.right)
	assert_eq(str(last), "player %d guesses %s, wrong" % [guesser, last.rule_id])


func test_a_right_guess_after_placing_wins() -> void:
	var current_match: Match = _started(1)
	var guesser: int = current_match.first_player()
	current_match.submit(guesser, Command.place(Vector2i(2, 3)))
	assert_true(current_match.submit(guesser, Command.guess(_true_id(Players.opponent(guesser)))))
	assert_eq(current_match.result().winner, guesser)
	assert_eq(current_match.result().reason, MatchResult.Reason.RIGHT_GUESS)
	assert_eq(current_match.history().size(), 3, "colour pick, placement, guess")


func test_a_wrong_guess_after_placing_loses() -> void:
	var current_match: Match = _started(1)
	var guesser: int = current_match.first_player()
	var opponent: int = Players.opponent(guesser)
	current_match.submit(guesser, Command.place(Vector2i(2, 3)))
	assert_true(current_match.submit(guesser, Command.guess(_fake_id(opponent))))
	assert_eq(current_match.result().winner, opponent)
	assert_eq(current_match.result().reason, MatchResult.Reason.WRONG_GUESS)


func test_a_guess_before_the_first_colour_pick_is_rejected() -> void:
	var current_match: Match = Fixtures.new_match(_book, Fixtures.anywhere(_book, "AT"), Fixtures.anywhere(_book, "BT"), 1)
	var second: int = Players.opponent(current_match.first_player())
	assert_false(current_match.submit(second, Command.guess(_true_id(current_match.first_player()))))
	assert_eq(current_match.phase(), Match.Phase.FIRST_COLOUR)
	assert_eq(current_match.history().size(), 0)
	assert_null(current_match.result())


func test_a_guess_on_the_opponents_turn_is_rejected() -> void:
	var current_match: Match = _started(1)
	var waiting: int = Players.opponent(current_match.first_player())
	assert_false(current_match.submit(waiting, Command.guess(_true_id(current_match.first_player()))))
	current_match.submit(current_match.first_player(), Command.place(Vector2i(2, 3)))
	assert_false(current_match.submit(waiting, Command.guess(_true_id(current_match.first_player()))))
	assert_eq(current_match.phase(), Match.Phase.PICK_COLOUR)
	assert_eq(current_match.history().size(), 2)


func test_the_window_closes_with_the_colour_pick() -> void:
	var current_match: Match = _started(1)
	var guesser: int = current_match.first_player()
	current_match.submit(guesser, Command.place(Vector2i(2, 3)))
	current_match.submit(guesser, Command.pick_colour(BallColour.BLUE))
	assert_false(current_match.submit(guesser, Command.guess(_true_id(Players.opponent(guesser)))))
	assert_eq(current_match.phase(), Match.Phase.PLACE)
	assert_null(current_match.result())


func test_the_opponent_can_guess_at_the_start_of_their_turn() -> void:
	var current_match: Match = _started(1)
	var first: int = current_match.first_player()
	var second: int = Players.opponent(first)
	current_match.submit(first, Command.place(Vector2i(2, 3)))
	current_match.submit(first, Command.pick_colour(BallColour.BLUE))
	assert_true(current_match.submit(second, Command.guess(_true_id(first))))
	assert_eq(current_match.result().winner, second)


func test_a_guess_after_the_match_is_over_is_rejected() -> void:
	var current_match: Match = _started(1)
	var guesser: int = current_match.first_player()
	var opponent: int = Players.opponent(guesser)
	current_match.submit(guesser, Command.guess(_fake_id(opponent)))
	assert_false(current_match.submit(guesser, Command.guess(_true_id(opponent))))
	assert_false(current_match.submit(opponent, Command.guess(_true_id(guesser))))
	assert_eq(current_match.result().winner, opponent)
	assert_eq(current_match.history().size(), 2)


func test_a_guess_naming_a_rule_outside_the_opponents_deck_is_rejected() -> void:
	var current_match: Match = _started(1)
	var guesser: int = current_match.first_player()
	assert_false(current_match.submit(guesser, Command.guess(_true_id(guesser))), "own rule")
	assert_false(current_match.submit(guesser, Command.guess("R99")), "unknown rule")
	assert_false(current_match.submit(guesser, Command.guess("")), "no rule")
	assert_eq(current_match.phase(), Match.Phase.PLACE)
	assert_eq(current_match.history().size(), 1)
	assert_null(current_match.result())


func test_the_view_shows_when_the_viewer_may_guess() -> void:
	var current_match: Match = Fixtures.new_match(_book, Fixtures.anywhere(_book, "AT"), Fixtures.anywhere(_book, "BT"), 1)
	var first: int = current_match.first_player()
	var second: int = Players.opponent(first)
	assert_false(current_match.public_view(second).can_guess(), "first colour pick")
	current_match.submit(second, Command.pick_colour(BallColour.RED))
	assert_true(current_match.public_view(first).can_guess(), "before placing")
	assert_false(current_match.public_view(second).can_guess(), "opponent's turn")
	current_match.submit(first, Command.place(Vector2i(2, 3)))
	assert_true(current_match.public_view(first).can_guess(), "after placing")
	assert_false(current_match.public_view(second).can_guess(), "opponent's turn")
	current_match.submit(first, Command.guess(_fake_id(second)))
	assert_false(current_match.public_view(first).can_guess(), "match over")
	assert_false(current_match.public_view(second).can_guess(), "match over")
