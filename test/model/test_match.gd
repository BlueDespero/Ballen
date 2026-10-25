extends GutTest

# The match seam: send commands, check phase, history and PublicView.

const Fixtures := preload("res://test/helpers/fixtures.gd")

var _book: RuleBook


func before_each() -> void:
	_book = Fixtures.book()


func _r04_match(seed_value: int) -> Match:
	var r04: Rule = _book.rule("R04")
	return Fixtures.new_match(_book, r04, r04, seed_value)


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
	var game: Match = _r04_match(1)
	var second: int = Players.opponent(game.first_player())
	assert_eq(game.phase(), Match.Phase.FIRST_COLOUR)
	assert_eq(game.awaiting_players(), [second] as Array[int])


func test_the_first_player_cannot_pick_the_first_colour() -> void:
	var game: Match = _r04_match(1)
	assert_false(game.submit(game.first_player(), Command.pick_colour(BallColour.RED)))
	assert_eq(game.phase(), Match.Phase.FIRST_COLOUR)
	assert_eq(game.history().size(), 0)


func test_the_first_colour_pick_starts_the_first_players_turn_in_that_colour() -> void:
	var game: Match = _r04_match(1)
	var first: int = game.first_player()
	assert_true(game.submit(Players.opponent(first), Command.pick_colour(BallColour.GREEN)))
	assert_eq(game.phase(), Match.Phase.PLACE)
	assert_eq(game.current_player(), first)
	assert_eq(game.current_colour(), BallColour.GREEN)
	assert_eq(game.turn(), 1)


func test_history_records_the_first_colour_pick() -> void:
	var game: Match = _r04_match(1)
	var second: int = Players.opponent(game.first_player())
	game.submit(second, Command.pick_colour(BallColour.BLUE))
	var history: Array[HistoryEntry] = game.history()
	assert_eq(history.size(), 1)
	assert_eq(history[0].type, HistoryEntry.Type.COLOUR_PICK)
	assert_eq(history[0].player, second)
	assert_eq(history[0].colour, BallColour.BLUE)


func test_an_unknown_colour_is_rejected() -> void:
	var game: Match = _r04_match(1)
	assert_false(game.submit(Players.opponent(game.first_player()), Command.pick_colour("purple")))
	assert_eq(game.phase(), Match.Phase.FIRST_COLOUR)


func test_a_placement_before_the_first_colour_pick_is_rejected() -> void:
	var game: Match = _r04_match(1)
	assert_false(game.submit(game.first_player(), Command.place(Vector2i(2, 2))))
	assert_false(game.submit(Players.opponent(game.first_player()), Command.place(Vector2i(2, 2))))
	assert_eq(game.history().size(), 0)
