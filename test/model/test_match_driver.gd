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


func _driver(current_match: Match, controllers: Array[Controller], paused_players: Array[int], seed_value: int) -> MatchDriver:
	return MatchDriver.new(current_match, controllers, paused_players, Fixtures.rng(seed_value), _record_wait)


## An AI that never guesses (no confidence reaches an infinite threshold), so
## matches run on to their skips.
func _ai(seed_value: int) -> AIController:
	return AIController.new(Fixtures.rng(seed_value), GuessPolicy.new(INF))


## A match where player 0 goes first, so the AI (player 1) picks their first colour.
func _player_0_first() -> Match:
	for seed_value: int in 100:
		var current_match: Match = _r04_match(seed_value)
		if current_match.first_player() == 0:
			return current_match
	return null


func _last(current_match: Match) -> HistoryEntry:
	var history: Array[HistoryEntry] = current_match.history()
	return history[-1]


func _count(current_match: Match, type: HistoryEntry.Type, player: int) -> int:
	var count: int = 0
	for entry: HistoryEntry in current_match.history():
		if entry.type == type and entry.player == player:
			count += 1
	return count


func test_two_ais_play_until_a_third_skip_ends_the_match() -> void:
	var current_match: Match = _r04_match(11)
	var controllers: Array[Controller] = [_ai(1), _ai(2)]
	var driver: MatchDriver = _driver(current_match, controllers, [], 3)
	watch_signals(driver)
	await driver.run()
	# R04 leaves the 16 inner cells; then the players skip in turn, the first
	# player 3 times and the second twice.
	var first: int = current_match.first_player()
	assert_eq(current_match.public_view(0).position.board.empty_cells().size(), 20)
	assert_eq(current_match.phase(), Match.Phase.OVER)
	assert_eq(current_match.result().winner, Players.opponent(first))
	assert_eq(current_match.result().reason, MatchResult.Reason.THIRD_SKIP)
	assert_eq(_count(current_match, HistoryEntry.Type.SKIP, first), 3)
	assert_eq(_count(current_match, HistoryEntry.Type.SKIP, Players.opponent(first)), 2)
	assert_eq(current_match.history().size(), 42, "1 first colour + 16 placements + 5 skips + 20 picks")
	assert_signal_emit_count(driver, "changed", 37, "skips are not commands")


func test_a_paused_player_waits_half_a_second_to_a_second_and_a_half_before_each_command() -> void:
	var current_match: Match = _r04_match(11)
	var controllers: Array[Controller] = [_ai(1), _ai(2)]
	await _driver(current_match, controllers, [1], 3).run()
	var commands_by_1: int = _count(current_match, HistoryEntry.Type.PLACEMENT, 1) + _count(current_match, HistoryEntry.Type.COLOUR_PICK, 1)
	assert_eq(_waits.size(), commands_by_1, "a pause each time player 1 is asked, none for player 0")
	for seconds: float in _waits:
		assert_between(seconds, 0.5, 1.5)
	var sorted: Array[float] = _waits.duplicate()
	sorted.sort()
	assert_gt(sorted[-1] - sorted[0], 0.5, "pauses vary")


func test_pauses_follow_the_seeded_rng() -> void:
	var controllers: Array[Controller] = [_ai(1), _ai(2)]
	await _driver(_r04_match(11), controllers, [0, 1], 3).run()
	var first_run: Array[float] = _waits.duplicate()
	_waits = []
	controllers = [_ai(1), _ai(2)]
	await _driver(_r04_match(11), controllers, [0, 1], 3).run()
	assert_eq(_waits.size(), 37, "one per command: 1 first colour, 16 placements, 20 picks")
	assert_eq(_waits, first_run)


func test_the_players_commands_are_submitted_when_they_choose_them() -> void:
	var current_match: Match = _player_0_first()
	var human: HumanController = HumanController.new()
	var controllers: Array[Controller] = [human, _ai(2)]
	var driver: MatchDriver = _driver(current_match, controllers, [1], 3)
	driver.run()
	assert_eq(current_match.phase(), Match.Phase.PLACE, "the AI picked the first colour; the driver now waits for the player")
	assert_eq(current_match.awaiting_players(), [0] as Array[int])
	human.choose(Command.place(Vector2i(2, 3)))
	assert_eq(str(_last(current_match)), str(HistoryEntry.placement(0, Vector2i(2, 3), current_match.current_colour())))
	human.choose(Command.pick_colour(BallColour.BLUE))
	var history: Array[HistoryEntry] = current_match.history()
	assert_eq(str(history[3]), str(HistoryEntry.placement(1, history[3].cell, BallColour.BLUE)), "the AI placed blue")
	assert_eq(history[4].type, HistoryEntry.Type.COLOUR_PICK)
	assert_eq(current_match.awaiting_players(), [0] as Array[int], "and handed the turn back")
	human.choose(null) # gives up the decision, ending run()


func test_a_rejected_command_is_asked_for_again() -> void:
	var current_match: Match = _player_0_first()
	var human: HumanController = HumanController.new()
	var controllers: Array[Controller] = [human, _ai(2)]
	var driver: MatchDriver = _driver(current_match, controllers, [1], 3)
	watch_signals(driver)
	driver.run()
	human.choose(Command.place(Vector2i(0, 0)))
	assert_eq(current_match.history().size(), 1, "R04 forbids the corner")
	human.choose(Command.place(Vector2i(2, 2)))
	assert_eq(_last(current_match).cell, Vector2i(2, 2))
	assert_signal_emit_count(driver, "changed", 2, "the first colour and the placement")
	human.choose(null) # gives up the decision, ending run()


func test_a_guess_ends_the_match_and_the_run() -> void:
	var current_match: Match = _player_0_first()
	var human: HumanController = HumanController.new()
	var controllers: Array[Controller] = [human, _ai(2)]
	var driver: MatchDriver = _driver(current_match, controllers, [1], 3)
	watch_signals(driver)
	driver.run()
	human.choose(Command.guess("R04"))
	assert_eq(current_match.phase(), Match.Phase.OVER)
	assert_eq(current_match.result().winner, 0)
	assert_eq(_last(current_match).type, HistoryEntry.Type.GUESS)
	assert_signal_emit_count(driver, "changed", 2, "the first colour and the guess")
	assert_eq(_waits.size(), 1, "the AI is not asked again after the guess")


func test_a_player_with_no_legal_cell_is_skipped_and_asked_for_a_colour() -> void:
	var position: MatchPosition = MatchPosition.new(Board.parse([
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
	var current_match: Match = Match.from_position(position, decks, true_rules, Fixtures.rng(1))
	var human: HumanController = HumanController.new()
	var controllers: Array[Controller] = [human, _ai(2)]
	var driver: MatchDriver = _driver(current_match, controllers, [1], 3)
	driver.run()
	assert_eq(str(_last(current_match)), "player 0 skips red")
	assert_eq(current_match.phase(), Match.Phase.PICK_COLOUR)
	assert_eq(current_match.awaiting_players(), [0] as Array[int], "the driver waits for the player's colour")
	human.choose(Command.pick_colour(BallColour.BLUE))
	var history: Array[HistoryEntry] = current_match.history()
	assert_eq(str(history[2]), "player 1 skips blue", "the AI had no legal cell either")
	assert_eq(history[3].type, HistoryEntry.Type.COLOUR_PICK)
	assert_eq(str(_last(current_match)), "player 0 skips %s" % history[3].colour)
	assert_eq(current_match.skip_count(0), 2)
	assert_eq(current_match.awaiting_players(), [0] as Array[int])
	human.choose(null) # gives up the decision, ending run()


func test_a_stopped_driver_submits_nothing_more() -> void:
	var current_match: Match = _player_0_first()
	var human: HumanController = HumanController.new()
	var controllers: Array[Controller] = [human, _ai(2)]
	var driver: MatchDriver = _driver(current_match, controllers, [1], 3)
	driver.run()
	driver.stop()
	human.choose(Command.place(Vector2i(2, 2)))
	assert_eq(current_match.history().size(), 1)
	assert_eq(current_match.phase(), Match.Phase.PLACE)
