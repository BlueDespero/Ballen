extends GutTest

# The AI seam on a full board: given a view where its forced guess is due, the
# AI names a random remaining candidate. Views come from real matches.

const Fixtures := preload("res://test/helpers/fixtures.gd")

var _book: RuleBook


func before_each() -> void:
	_book = Fixtures.book()


## The nearly full match after player 0 fills the board.
func _full() -> Match:
	var game: Match = Fixtures.nearly_full_match(_book)
	assert_true(game.submit(0, Command.place(Fixtures.LAST_EMPTY_CELL)))
	return game


func test_the_ai_makes_its_forced_guess_naming_a_rule_of_the_opponents_deck() -> void:
	for player: int in Players.COUNT:
		var game: Match = _full()
		if player == 1:
			game.submit(0, Command.forced_guess("B1"))
		var command: Command = await AIController.new(Fixtures.rng(1)).decide(game.public_view(player))
		assert_eq(command.type, Command.Type.FORCED_GUESS, "player %d" % player)
		assert_true(game.public_view(player).decks[Players.opponent(player)].has_id(command.rule_id))
		assert_true(game.submit(player, command))


func test_the_ais_forced_guess_follows_its_seeded_rng() -> void:
	var view: PublicView = _full().public_view(0)
	var named: Array[String] = []
	for seed_value: int in 20:
		var first: Command = await AIController.new(Fixtures.rng(seed_value)).decide(view)
		var again: Command = await AIController.new(Fixtures.rng(seed_value)).decide(view)
		assert_eq(first.rule_id, again.rule_id)
		if not named.has(first.rule_id):
			named.append(first.rule_id)
	assert_gt(named.size(), 1, "different seeds name different rules")


func test_the_ais_forced_guess_names_a_random_remaining_candidate() -> void:
	# Player 0's deck: a permissive true rule "AT", permissive A1 and A2, and
	# N3 and N4, which allow no cell. Filling the board rules N3 and N4 out.
	_book.add_template("nowhere", {"blanks": {}, "tree": {"part": "count_at_most", "n": 0, "of": {"part": "target"}}})
	var deck_0: Array[Rule] = [Fixtures.anywhere(_book, "AT"), Fixtures.anywhere(_book, "A1"), Fixtures.anywhere(_book, "A2")]
	for rule_id: String in ["N3", "N4"]:
		deck_0.append(_book.make_rule({"id": rule_id, "text": "Nowhere", "template": "nowhere", "values": {}}))
	var start: PublicView = Fixtures.nearly_full_match(_book).public_view(1)
	var decks: Array[Deck] = [Deck.new(deck_0), start.decks[1]]
	var true_rules: Array[Rule] = [deck_0[0], start.own_true_rule]
	var game: Match = Match.from_position(start.position, decks, true_rules, Fixtures.rng(1))
	assert_true(game.submit(0, Command.place(Fixtures.LAST_EMPTY_CELL)))
	assert_true(game.submit(0, Command.forced_guess("B1")))
	var view: PublicView = game.public_view(1)
	var named: Array[String] = []
	for seed_value: int in 20:
		var command: Command = await AIController.new(Fixtures.rng(seed_value)).decide(view)
		assert_eq(command.type, Command.Type.FORCED_GUESS)
		assert_has(["AT", "A1", "A2"], command.rule_id)
		if not named.has(command.rule_id):
			named.append(command.rule_id)
	assert_gt(named.size(), 1, "different seeds name different candidates")


func test_two_ais_fill_the_board_and_end_on_their_forced_guesses() -> void:
	for seed_value: int in 5:
		var game: Match = Fixtures.new_match(_book, Fixtures.anywhere(_book, "AT"), Fixtures.anywhere(_book, "BT"), seed_value)
		var controllers: Array[Controller] = [AIController.new(Fixtures.rng(seed_value)), AIController.new(Fixtures.rng(seed_value + 100))]
		await MatchDriver.new(game, controllers, [], Fixtures.rng(seed_value), func(_seconds: float) -> void: pass).run()
		assert_eq(game.phase(), Match.Phase.OVER)
		assert_eq(game.result().reason, MatchResult.Reason.FORCED_GUESSES)
		assert_true(game.public_view(0).position.board.is_full())


func test_an_ai_that_fills_the_board_with_one_candidate_left_guesses_outright() -> void:
	# Player 1's deck: the permissive true rule "BT" and N1..N4, which allow no
	# cell. Player 1's recorded placement at (1, 0) rules N1..N4 out.
	_book.add_template("nowhere", {"blanks": {}, "tree": {"part": "count_at_most", "n": 0, "of": {"part": "target"}}})
	var deck_1: Array[Rule] = [Fixtures.anywhere(_book, "BT")]
	for i: int in range(1, Deck.SIZE):
		deck_1.append(_book.make_rule({"id": "N%d" % i, "text": "Nowhere", "template": "nowhere", "values": {}}))
	var start: PublicView = Fixtures.nearly_full_match(_book).public_view(0)
	var position: MatchPosition = start.position
	position.history = [HistoryEntry.placement(1, Vector2i(1, 0), BallColour.BLUE)]
	var decks: Array[Deck] = [start.decks[0], Deck.new(deck_1)]
	var true_rules: Array[Rule] = [start.own_true_rule, deck_1[0]]
	var game: Match = Match.from_position(position, decks, true_rules, Fixtures.rng(1))
	assert_true(game.submit(0, Command.place(Fixtures.LAST_EMPTY_CELL)))
	var command: Command = await AIController.new(Fixtures.rng(1)).decide(game.public_view(0))
	assert_eq(command.type, Command.Type.GUESS, "an outright guess, not a sealed forced guess")
	assert_eq(command.rule_id, "BT")
	assert_true(game.submit(0, command))
	assert_eq(game.result().winner, 0)
	assert_eq(game.result().reason, MatchResult.Reason.RIGHT_GUESS)
