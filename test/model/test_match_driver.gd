extends GutTest

# The match driver as the scene uses it: controllers in, commands submitted to
# a real match, signals and pauses out. Waits are recorded, never slept.

const Fixtures := preload("res://test/helpers/fixtures.gd")

var _book: RuleBook
var _waits: Array[float] = []


func before_each() -> void:
	_book = Fixtures.book()
	_waits = []


func _r04_match(seed_value: int) -> Match:
	var r04: Rule = _book.rule("R04")
	return Fixtures.new_match(_book, r04, r04, seed_value)


func _record_wait(seconds: float) -> void:
	_waits.append(seconds)


func _driver(game: Match, controllers: Array[Controller], paused_players: Array[int], seed_value: int) -> MatchDriver:
	return MatchDriver.new(game, controllers, paused_players, Fixtures.rng(seed_value), _record_wait)


## A match where player 0 goes first, so the AI (player 1) picks their first colour.
func _player_0_first() -> Match:
	for seed_value: int in 100:
		var game: Match = _r04_match(seed_value)
		if game.first_player() == 0:
			return game
	return null


func _last(game: Match) -> HistoryEntry:
	var history: Array[HistoryEntry] = game.history()
	return history[-1]


func _count(game: Match, type: HistoryEntry.Type, player: int) -> int:
	var count: int = 0
	for entry: HistoryEntry in game.history():
		if entry.type == type and entry.player == player:
			count += 1
	return count


func test_two_ais_play_until_a_player_has_no_legal_cell() -> void:
	var game: Match = _r04_match(11)
	var controllers: Array[Controller] = [AIController.new(Fixtures.rng(1)), AIController.new(Fixtures.rng(2))]
	var driver: MatchDriver = _driver(game, controllers, [], 3)
	watch_signals(driver)
	await driver.run()
	# R04 leaves the 16 inner cells; without skips (a later ticket) play stops there.
	assert_eq(game.public_view(0).position.board.empty_cells().size(), 20)
	assert_eq(game.history().size(), 33, "1 first colour + 16 placements + 16 picks")
	assert_signal_emit_count(driver, "changed", 33)
	assert_signal_emitted_with_parameters(driver, "stalled", [game.current_player()])


func test_a_paused_player_waits_half_a_second_to_a_second_and_a_half_before_each_command() -> void:
	var game: Match = _r04_match(11)
	var controllers: Array[Controller] = [AIController.new(Fixtures.rng(1)), AIController.new(Fixtures.rng(2))]
	await _driver(game, controllers, [1], 3).run()
	var commands_by_1: int = _count(game, HistoryEntry.Type.PLACEMENT, 1) + _count(game, HistoryEntry.Type.COLOUR_PICK, 1)
	var asks_of_1: int = commands_by_1 + (1 if game.current_player() == 1 else 0)
	assert_eq(_waits.size(), asks_of_1, "a pause each time player 1 is asked (also when it stalls), none for player 0")
	for seconds: float in _waits:
		assert_between(seconds, 0.5, 1.5)
	var sorted: Array[float] = _waits.duplicate()
	sorted.sort()
	assert_gt(sorted[-1] - sorted[0], 0.5, "pauses vary")


func test_pauses_follow_the_seeded_rng() -> void:
	var controllers: Array[Controller] = [AIController.new(Fixtures.rng(1)), AIController.new(Fixtures.rng(2))]
	await _driver(_r04_match(11), controllers, [0, 1], 3).run()
	var first_run: Array[float] = _waits.duplicate()
	_waits = []
	controllers = [AIController.new(Fixtures.rng(1)), AIController.new(Fixtures.rng(2))]
	await _driver(_r04_match(11), controllers, [0, 1], 3).run()
	assert_eq(_waits.size(), 34, "33 commands, then the stalled player is asked once more")
	assert_eq(_waits, first_run)


func test_the_players_commands_are_submitted_when_they_choose_them() -> void:
	var game: Match = _player_0_first()
	var human: HumanController = HumanController.new()
	var controllers: Array[Controller] = [human, AIController.new(Fixtures.rng(2))]
	var driver: MatchDriver = _driver(game, controllers, [1], 3)
	driver.run()
	assert_eq(game.phase(), Match.Phase.PLACE, "the AI picked the first colour; the driver now waits for the player")
	assert_eq(game.awaiting_players(), [0] as Array[int])
	human.choose(Command.place(Vector2i(2, 3)))
	assert_eq(str(_last(game)), str(HistoryEntry.placement(0, Vector2i(2, 3), game.current_colour())))
	human.choose(Command.pick_colour(BallColour.BLUE))
	var history: Array[HistoryEntry] = game.history()
	assert_eq(str(history[3]), str(HistoryEntry.placement(1, history[3].cell, BallColour.BLUE)), "the AI placed blue")
	assert_eq(history[4].type, HistoryEntry.Type.COLOUR_PICK)
	assert_eq(game.awaiting_players(), [0] as Array[int], "and handed the turn back")
	human.choose(null) # gives up the decision, ending run()


func test_a_rejected_command_is_asked_for_again() -> void:
	var game: Match = _player_0_first()
	var human: HumanController = HumanController.new()
	var controllers: Array[Controller] = [human, AIController.new(Fixtures.rng(2))]
	var driver: MatchDriver = _driver(game, controllers, [1], 3)
	watch_signals(driver)
	driver.run()
	human.choose(Command.place(Vector2i(0, 0)))
	assert_eq(game.history().size(), 1, "R04 forbids the corner")
	human.choose(Command.place(Vector2i(2, 2)))
	assert_eq(_last(game).cell, Vector2i(2, 2))
	assert_signal_emit_count(driver, "changed", 2, "the first colour and the placement")
	human.choose(null) # gives up the decision, ending run()


func test_the_player_stalls_the_driver_when_they_have_no_legal_cell() -> void:
	var position: MatchPosition = MatchPosition.from_board(Board.parse([
		"......",
		".RbRb.",
		".bRbR.",
		".RbRb.",
		".bRbR.",
		"......",
	]), 0)
	position.turn = 17
	position.colour = BallColour.RED
	var r04: Rule = _book.rule("R04")
	var decks: Array[Deck] = [Fixtures.deck_with(_book, r04, "A"), Fixtures.deck_with(_book, r04, "B")]
	var true_rules: Array[Rule] = [r04, r04]
	var game: Match = Match.from_position(position, decks, true_rules, Fixtures.rng(1))
	var human: HumanController = HumanController.new()
	var controllers: Array[Controller] = [human, AIController.new(Fixtures.rng(2))]
	var driver: MatchDriver = _driver(game, controllers, [1], 3)
	watch_signals(driver)
	driver.run()
	assert_signal_emitted_with_parameters(driver, "stalled", [0])
	driver.stop()
	human.choose(null) # releases run() if it is still waiting on the player


func test_a_stopped_driver_submits_nothing_more() -> void:
	var game: Match = _player_0_first()
	var human: HumanController = HumanController.new()
	var controllers: Array[Controller] = [human, AIController.new(Fixtures.rng(2))]
	var driver: MatchDriver = _driver(game, controllers, [1], 3)
	driver.run()
	driver.stop()
	human.choose(Command.place(Vector2i(2, 2)))
	assert_eq(game.history().size(), 1)
	assert_eq(game.phase(), Match.Phase.PLACE)
