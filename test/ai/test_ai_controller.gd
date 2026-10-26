extends GutTest

# The AI seam: given a PublicView, check the decision it returns. Views come
# from real matches.

const Fixtures := preload("res://test/helpers/fixtures.gd")

var _book: RuleBook


func before_each() -> void:
	_book = Fixtures.book()


func _r04_match(seed_value: int) -> Match:
	var r04: Rule = _book.rule("R04")
	return Fixtures.new_match(_book, r04, r04, seed_value)


func test_the_ai_picks_one_of_the_four_colours_for_the_first_ball() -> void:
	var current_match: Match = _r04_match(1)
	var picker: int = current_match.awaiting_players()[0]
	var command: Command = await AIController.new(Fixtures.rng(5)).decide(current_match.public_view(picker))
	assert_eq(command.type, Command.Type.PICK_COLOUR)
	assert_has(BallColour.ALL, command.colour)
	assert_true(current_match.submit(picker, command))


func test_the_ai_places_on_one_of_its_legal_cells() -> void:
	for seed_value: int in 20:
		var current_match: Match = _r04_match(seed_value)
		current_match.submit(current_match.awaiting_players()[0], Command.pick_colour(BallColour.RED))
		var player: int = current_match.current_player()
		var command: Command = await AIController.new(Fixtures.rng(seed_value)).decide(current_match.public_view(player))
		assert_eq(command.type, Command.Type.PLACE)
		assert_false(Board.is_on_edge(command.cell), "R04 forbids %s" % command.cell)
		assert_true(current_match.submit(player, command))


func test_the_ais_choices_follow_its_seeded_rng() -> void:
	var cells: Array[Vector2i] = []
	for seed_value: int in 10:
		var current_match: Match = _r04_match(1)
		current_match.submit(current_match.awaiting_players()[0], Command.pick_colour(BallColour.RED))
		var view: PublicView = current_match.public_view(current_match.current_player())
		var first: Command = await AIController.new(Fixtures.rng(seed_value)).decide(view)
		var again: Command = await AIController.new(Fixtures.rng(seed_value)).decide(view)
		assert_eq(first.cell, again.cell)
		if not cells.has(first.cell):
			cells.append(first.cell)
	assert_gt(cells.size(), 1, "different seeds pick different cells")


func test_two_ai_controllers_play_entirely_in_code_until_one_guesses() -> void:
	var current_match: Match = _r04_match(11)
	var controllers: Array[Controller] = [AIController.new(Fixtures.rng(1)), AIController.new(Fixtures.rng(2))]
	# R04 leaves the 16 inner cells. Once they are full the first player skips,
	# which rules out the permissive rest of their deck; the second player then
	# skips too and names R04.
	while current_match.phase() != Match.Phase.OVER:
		var player: int = current_match.awaiting_players()[0]
		var command: Command = await controllers[player].decide(current_match.public_view(player))
		assert_true(current_match.submit(player, command), "player %d: %s" % [player, command])
	var placements: Array[HistoryEntry] = []
	for entry: HistoryEntry in current_match.history():
		if entry.type == HistoryEntry.Type.PLACEMENT:
			placements.append(entry)
	assert_eq(placements.size(), 16)
	for i: int in placements.size():
		var expected_player: int = current_match.first_player() if i % 2 == 0 else Players.opponent(current_match.first_player())
		assert_eq(placements[i].player, expected_player, "placements alternate")
		assert_false(Board.is_on_edge(placements[i].cell))
	var second: int = Players.opponent(current_match.first_player())
	var history: Array[HistoryEntry] = current_match.history()
	assert_eq(history[-4].type, HistoryEntry.Type.SKIP)
	assert_eq(history[-4].player, current_match.first_player())
	assert_eq(history[-2].type, HistoryEntry.Type.SKIP)
	assert_eq(history[-2].player, second)
	assert_eq(str(history[-1]), "player %d guesses R04, right" % second, "guesses after its own skip")
	assert_eq(current_match.result().winner, second)
	assert_eq(current_match.result().reason, MatchResult.Reason.RIGHT_GUESS)
