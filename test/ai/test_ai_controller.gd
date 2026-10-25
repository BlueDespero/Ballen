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
	var game: Match = _r04_match(1)
	var picker: int = game.awaiting_players()[0]
	var command: Command = await AIController.new(Fixtures.rng(5)).decide(game.public_view(picker))
	assert_eq(command.type, Command.Type.PICK_COLOUR)
	assert_has(BallColour.ALL, command.colour)
	assert_true(game.submit(picker, command))


func test_the_ai_places_on_one_of_its_legal_cells() -> void:
	for seed_value: int in 20:
		var game: Match = _r04_match(seed_value)
		game.submit(game.awaiting_players()[0], Command.pick_colour(BallColour.RED))
		var player: int = game.current_player()
		var command: Command = await AIController.new(Fixtures.rng(seed_value)).decide(game.public_view(player))
		assert_eq(command.type, Command.Type.PLACE)
		assert_false(Board.is_on_edge(command.cell), "R04 forbids %s" % command.cell)
		assert_true(game.submit(player, command))


func test_the_ais_choices_follow_its_seeded_rng() -> void:
	var cells: Array[Vector2i] = []
	for seed_value: int in 10:
		var game: Match = _r04_match(1)
		game.submit(game.awaiting_players()[0], Command.pick_colour(BallColour.RED))
		var view: PublicView = game.public_view(game.current_player())
		var first: Command = await AIController.new(Fixtures.rng(seed_value)).decide(view)
		var again: Command = await AIController.new(Fixtures.rng(seed_value)).decide(view)
		assert_eq(first.cell, again.cell)
		if not cells.has(first.cell):
			cells.append(first.cell)
	assert_gt(cells.size(), 1, "different seeds pick different cells")


func test_two_ai_controllers_play_alternating_turns_entirely_in_code() -> void:
	var game: Match = _r04_match(11)
	var controllers: Array[Controller] = [AIController.new(Fixtures.rng(1)), AIController.new(Fixtures.rng(2))]
	# Without skips (a later ticket) play stops when the current player has no
	# legal cell: R04 leaves the 16 inner cells.
	while not (game.phase() == Match.Phase.PLACE and game.legal_cells().is_empty()):
		var player: int = game.awaiting_players()[0]
		var command: Command = await controllers[player].decide(game.public_view(player))
		assert_true(game.submit(player, command), "player %d: %s" % [player, command])
	var placements: Array[HistoryEntry] = []
	for entry: HistoryEntry in game.history():
		if entry.type == HistoryEntry.Type.PLACEMENT:
			placements.append(entry)
	assert_eq(placements.size(), 16)
	for i: int in placements.size():
		var expected_player: int = game.first_player() if i % 2 == 0 else Players.opponent(game.first_player())
		assert_eq(placements[i].player, expected_player, "placements alternate")
		assert_false(Board.is_on_edge(placements[i].cell))
