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
	var game: Match = Fixtures.new_match(_book, Fixtures.anywhere(_book, "AT"), Fixtures.anywhere(_book, "BT"), seed_value)
	game.submit(Players.opponent(game.first_player()), Command.pick_colour(BallColour.RED))
	return game


## The id of the true rule in this player's deck.
func _true_id(player: int) -> String:
	return "AT" if player == 0 else "BT"


## The id of a fake rule in this player's deck.
func _fake_id(player: int) -> String:
	return "A2" if player == 0 else "B2"


func test_a_right_guess_at_the_start_of_the_turn_wins() -> void:
	var game: Match = _started(1)
	var guesser: int = game.first_player()
	assert_true(game.submit(guesser, Command.guess(_true_id(Players.opponent(guesser)))))
	assert_eq(game.phase(), Match.Phase.OVER)
	assert_eq(game.result().winner, guesser)
	assert_eq(game.result().reason, MatchResult.Reason.RIGHT_GUESS)
	assert_eq(game.awaiting_players(), [] as Array[int])


func test_a_wrong_guess_at_the_start_of_the_turn_loses() -> void:
	var game: Match = _started(1)
	var guesser: int = game.first_player()
	var opponent: int = Players.opponent(guesser)
	assert_true(game.submit(guesser, Command.guess(_fake_id(opponent))))
	assert_eq(game.phase(), Match.Phase.OVER)
	assert_eq(game.result().winner, opponent)
	assert_eq(game.result().reason, MatchResult.Reason.WRONG_GUESS)


func test_history_records_a_right_guess() -> void:
	var game: Match = _started(1)
	var guesser: int = game.first_player()
	game.submit(guesser, Command.guess(_true_id(Players.opponent(guesser))))
	var last: HistoryEntry = game.history().back()
	assert_eq(last.type, HistoryEntry.Type.GUESS)
	assert_eq(last.player, guesser)
	assert_eq(last.rule_id, _true_id(Players.opponent(guesser)))
	assert_true(last.right)
	assert_eq(str(last), "player %d guesses %s, right" % [guesser, last.rule_id])


func test_history_records_a_wrong_guess() -> void:
	var game: Match = _started(1)
	var guesser: int = game.first_player()
	game.submit(guesser, Command.guess(_fake_id(Players.opponent(guesser))))
	var last: HistoryEntry = game.history().back()
	assert_eq(last.type, HistoryEntry.Type.GUESS)
	assert_eq(last.player, guesser)
	assert_eq(last.rule_id, _fake_id(Players.opponent(guesser)))
	assert_false(last.right)
	assert_eq(str(last), "player %d guesses %s, wrong" % [guesser, last.rule_id])


func test_a_right_guess_after_placing_wins() -> void:
	var game: Match = _started(1)
	var guesser: int = game.first_player()
	game.submit(guesser, Command.place(Vector2i(2, 3)))
	assert_true(game.submit(guesser, Command.guess(_true_id(Players.opponent(guesser)))))
	assert_eq(game.result().winner, guesser)
	assert_eq(game.result().reason, MatchResult.Reason.RIGHT_GUESS)
	assert_eq(game.history().size(), 3, "colour pick, placement, guess")


func test_a_wrong_guess_after_placing_loses() -> void:
	var game: Match = _started(1)
	var guesser: int = game.first_player()
	var opponent: int = Players.opponent(guesser)
	game.submit(guesser, Command.place(Vector2i(2, 3)))
	assert_true(game.submit(guesser, Command.guess(_fake_id(opponent))))
	assert_eq(game.result().winner, opponent)
	assert_eq(game.result().reason, MatchResult.Reason.WRONG_GUESS)


func test_a_guess_before_the_first_colour_pick_is_rejected() -> void:
	var game: Match = Fixtures.new_match(_book, Fixtures.anywhere(_book, "AT"), Fixtures.anywhere(_book, "BT"), 1)
	var second: int = Players.opponent(game.first_player())
	assert_false(game.submit(second, Command.guess(_true_id(game.first_player()))))
	assert_eq(game.phase(), Match.Phase.FIRST_COLOUR)
	assert_eq(game.history().size(), 0)
	assert_null(game.result())


func test_a_guess_on_the_opponents_turn_is_rejected() -> void:
	var game: Match = _started(1)
	var waiting: int = Players.opponent(game.first_player())
	assert_false(game.submit(waiting, Command.guess(_true_id(game.first_player()))))
	game.submit(game.first_player(), Command.place(Vector2i(2, 3)))
	assert_false(game.submit(waiting, Command.guess(_true_id(game.first_player()))))
	assert_eq(game.phase(), Match.Phase.PICK_COLOUR)
	assert_eq(game.history().size(), 2)


func test_the_window_closes_with_the_colour_pick() -> void:
	var game: Match = _started(1)
	var guesser: int = game.first_player()
	game.submit(guesser, Command.place(Vector2i(2, 3)))
	game.submit(guesser, Command.pick_colour(BallColour.BLUE))
	assert_false(game.submit(guesser, Command.guess(_true_id(Players.opponent(guesser)))))
	assert_eq(game.phase(), Match.Phase.PLACE)
	assert_null(game.result())


func test_the_opponent_can_guess_at_the_start_of_their_turn() -> void:
	var game: Match = _started(1)
	var first: int = game.first_player()
	var second: int = Players.opponent(first)
	game.submit(first, Command.place(Vector2i(2, 3)))
	game.submit(first, Command.pick_colour(BallColour.BLUE))
	assert_true(game.submit(second, Command.guess(_true_id(first))))
	assert_eq(game.result().winner, second)


func test_a_guess_after_the_match_is_over_is_rejected() -> void:
	var game: Match = _started(1)
	var guesser: int = game.first_player()
	var opponent: int = Players.opponent(guesser)
	game.submit(guesser, Command.guess(_fake_id(opponent)))
	assert_false(game.submit(guesser, Command.guess(_true_id(opponent))))
	assert_false(game.submit(opponent, Command.guess(_true_id(guesser))))
	assert_eq(game.result().winner, opponent)
	assert_eq(game.history().size(), 2)


func test_a_guess_naming_a_rule_outside_the_opponents_deck_is_rejected() -> void:
	var game: Match = _started(1)
	var guesser: int = game.first_player()
	assert_false(game.submit(guesser, Command.guess(_true_id(guesser))), "own rule")
	assert_false(game.submit(guesser, Command.guess("R99")), "unknown rule")
	assert_false(game.submit(guesser, Command.guess("")), "no rule")
	assert_eq(game.phase(), Match.Phase.PLACE)
	assert_eq(game.history().size(), 1)
	assert_null(game.result())


func test_the_view_shows_when_the_viewer_may_guess() -> void:
	var game: Match = Fixtures.new_match(_book, Fixtures.anywhere(_book, "AT"), Fixtures.anywhere(_book, "BT"), 1)
	var first: int = game.first_player()
	var second: int = Players.opponent(first)
	assert_false(game.public_view(second).can_guess(), "first colour pick")
	game.submit(second, Command.pick_colour(BallColour.RED))
	assert_true(game.public_view(first).can_guess(), "before placing")
	assert_false(game.public_view(second).can_guess(), "opponent's turn")
	game.submit(first, Command.place(Vector2i(2, 3)))
	assert_true(game.public_view(first).can_guess(), "after placing")
	assert_false(game.public_view(second).can_guess(), "opponent's turn")
	game.submit(first, Command.guess(_fake_id(second)))
	assert_false(game.public_view(first).can_guess(), "match over")
	assert_false(game.public_view(second).can_guess(), "match over")
