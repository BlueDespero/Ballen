extends GutTest

# The AI seam on a full board: given a view where its forced guess is due, the
# placeholder AI names a random rule of the opponent's deck. Views come from
# real matches.

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


func test_two_ais_fill_the_board_and_end_on_their_forced_guesses() -> void:
	for seed_value: int in 5:
		var game: Match = Fixtures.new_match(_book, Fixtures.anywhere(_book, "AT"), Fixtures.anywhere(_book, "BT"), seed_value)
		var controllers: Array[Controller] = [AIController.new(Fixtures.rng(seed_value)), AIController.new(Fixtures.rng(seed_value + 100))]
		await MatchDriver.new(game, controllers, [], Fixtures.rng(seed_value), func(_seconds: float) -> void: pass).run()
		assert_eq(game.phase(), Match.Phase.OVER)
		assert_eq(game.result().reason, MatchResult.Reason.FORCED_GUESSES)
		assert_true(game.public_view(0).position.board.is_full())
