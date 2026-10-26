extends GutTest

# Setting up a single-player match: the player's starter deck, the AI's random
# deck and true rule, then the match itself (checked through its PublicView).

const Fixtures := preload("res://test/helpers/fixtures.gd")

const PLAYER: int = MatchSetup.PLAYER
const AI: int = MatchSetup.AI

var _book: RuleBook


func before_each() -> void:
	_book = Fixtures.book()


func _ids(deck: Deck) -> Array[String]:
	var ids: Array[String] = []
	for rule: Rule in deck.rules:
		ids.append(rule.id)
	return ids


func _setup(seed_value: int) -> MatchSetup:
	return MatchSetup.against_ai(_book, Fixtures.rng(seed_value))


func test_the_player_gets_the_starter_deck() -> void:
	var expected: Array[String] = ["R01", "R03", "R05", "R08", "R18"]
	assert_eq(_ids(_setup(1).deck(PLAYER)), expected)


func test_the_ai_gets_5_distinct_rules_that_follow_the_seed() -> void:
	var ids: Array[String] = _ids(_setup(4).deck(AI))
	assert_eq(ids.size(), Deck.SIZE)
	for rule_id: String in ids:
		assert_eq(ids.count(rule_id), 1, "%s drawn once" % rule_id)
	assert_eq(ids, _ids(_setup(4).deck(AI)))


func test_the_tapped_rule_is_the_player_s_true_rule() -> void:
	var setup: MatchSetup = _setup(2)
	var r08: Rule = _book.rule("R08")
	var current_match: Match = setup.start(setup.deck(PLAYER).rules[3])
	assert_same(current_match.public_view(PLAYER).own_true_rule, r08)


func test_the_match_starts_with_both_decks_visible_to_the_player() -> void:
	var setup: MatchSetup = _setup(5)
	var view: PublicView = setup.start(_book.rule("R01")).public_view(PLAYER)
	assert_eq(view.phase, Match.Phase.FIRST_COLOUR)
	assert_eq(view.position.turn, 0)
	assert_eq(_ids(view.decks[PLAYER]), _ids(setup.deck(PLAYER)))
	assert_eq(_ids(view.decks[AI]), _ids(setup.deck(AI)))


func test_the_ai_s_true_rule_is_a_random_rule_of_its_deck() -> void:
	var positions: Array[int] = []
	for seed_value: int in 20:
		var setup: MatchSetup = _setup(seed_value)
		var ai_true: Rule = setup.start(_book.rule("R01")).public_view(AI).own_true_rule
		var position: int = setup.deck(AI).rules.find(ai_true)
		assert_ne(position, -1, "seed %d: the AI's true rule is in its deck" % seed_value)
		if not positions.has(position):
			positions.append(position)
	assert_gt(positions.size(), 1, "the true rule is not always the same slot of the deck")


func test_the_setup_follows_the_seeded_rng() -> void:
	var first: Match = _setup(9).start(_book.rule("R05"))
	var again: Match = _setup(9).start(_book.rule("R05"))
	assert_eq(again.public_view(AI).own_true_rule, first.public_view(AI).own_true_rule)
	assert_eq(again.first_player(), first.first_player())


func test_a_rule_outside_the_starter_deck_starts_no_match() -> void:
	assert_null(_setup(1).start(_book.rule("R04")))
	assert_push_error("true rule")


# Rematch

func test_a_rematch_lets_the_other_player_go_first() -> void:
	for seed_value: int in 6:
		var setup: MatchSetup = _setup(seed_value)
		var first: Match = setup.start(_book.rule("R01"))
		var rematch: Match = setup.rematch(_book.rule("R03"))
		assert_eq(rematch.first_player(), Players.opponent(first.first_player()), "seed %d" % seed_value)


func test_a_rematch_keeps_both_decks_and_takes_the_new_true_rule() -> void:
	var setup: MatchSetup = _setup(7)
	var first: PublicView = setup.start(_book.rule("R01")).public_view(PLAYER)
	var view: PublicView = setup.rematch(_book.rule("R18")).public_view(PLAYER)
	assert_eq(view.phase, Match.Phase.FIRST_COLOUR)
	assert_eq(view.position.turn, 0)
	assert_eq(_ids(view.decks[PLAYER]), _ids(first.decks[PLAYER]))
	assert_eq(_ids(view.decks[AI]), _ids(first.decks[AI]))
	assert_same(view.own_true_rule, _book.rule("R18"))


func test_a_rematch_draws_the_ai_a_new_true_rule_from_its_deck() -> void:
	var changed: int = 0
	for seed_value: int in 20:
		var setup: MatchSetup = _setup(seed_value)
		var before: Rule = setup.start(_book.rule("R01")).public_view(AI).own_true_rule
		var after: Rule = setup.rematch(_book.rule("R01")).public_view(AI).own_true_rule
		assert_true(setup.deck(AI).has(after), "seed %d: the new true rule is in the AI's deck" % seed_value)
		if after != before:
			changed += 1
	assert_gt(changed, 0, "the rematch draws again rather than keeping the true rule")


func test_rematches_keep_alternating_the_first_player() -> void:
	var setup: MatchSetup = _setup(3)
	var first: int = setup.start(_book.rule("R01")).first_player()
	assert_eq(setup.rematch(_book.rule("R01")).first_player(), Players.opponent(first))
	assert_eq(setup.rematch(_book.rule("R01")).first_player(), first)
	assert_eq(setup.rematch(_book.rule("R01")).first_player(), Players.opponent(first))


func test_a_rematch_numbers_rows_from_the_new_first_player_s_side() -> void:
	# R03 "Only on even rows": rows count from the first player's side, and the
	# player's side is the bottom (y = 5), the AI's the top (y = 0).
	for seed_value: int in 8:
		var setup: MatchSetup = _setup(seed_value)
		setup.start(_book.rule("R01"))
		var current_match: Match = setup.rematch(_book.rule("R03"))
		var even_rows_y: Array = [0, 2, 4] if current_match.first_player() == PLAYER else [1, 3, 5]
		_play_until_the_player_places(current_match)
		var legal: Array[Vector2i] = current_match.public_view(PLAYER).own_legal_cells()
		assert_gt(legal.size(), 0, "seed %d" % seed_value)
		for cell: Vector2i in legal:
			assert_has(even_rows_y, cell.y, "seed %d: %s is on an even row" % [seed_value, cell])


## Picks the first colour and, if the AI goes first, plays its first turn.
func _play_until_the_player_places(current_match: Match) -> void:
	current_match.submit(current_match.current_player(), Command.pick_colour(BallColour.RED))
	if current_match.current_player() == AI:
		current_match.submit(AI, Command.place(current_match.legal_cells()[0]))
		current_match.submit(AI, Command.pick_colour(BallColour.BLUE))


func test_a_book_without_the_starter_deck_sets_up_nothing() -> void:
	assert_null(MatchSetup.against_ai(RuleBook.new(), Fixtures.rng(1)))
	assert_push_error("starter deck")


func test_a_rematch_before_any_match_starts_nothing() -> void:
	assert_null(_setup(1).rematch(_book.rule("R01")))
	assert_push_error("no match")
