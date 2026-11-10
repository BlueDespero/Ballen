extends GutTest

# Match.resume continues a match exactly where a position stands, in the
# phase given, for Hard's look-ahead.

const Fixtures := preload("res://test/helpers/fixtures.gd")

var _book: RuleBook


func before_each() -> void:
	_book = Fixtures.book()


func _decks() -> Array[Deck]:
	return [Fixtures.deck_with(_book, _book.rule("R04"), "A"), Fixtures.deck_with(_book, _book.rule("R01"), "B")]


func _secrets(decks: Array[Deck]) -> Array[Rule]:
	return [decks[0].rules[0], decks[1].rules[0]]


func test_a_match_resumed_after_a_placement_waits_for_the_colour_pick() -> void:
	var decks: Array[Deck] = _decks()
	var played: Match = Match.create(decks, _secrets(decks), Fixtures.rng(1), 0)
	assert_true(played.submit(1, Command.pick_colour(BallColour.RED)))
	assert_true(played.submit(0, Command.place(Vector2i(2, 2))))
	var view: PublicView = played.public_view(0)
	var resumed: Match = Match.resume(view.position, decks, _secrets(decks), Fixtures.rng(2), view.phase)
	assert_eq(resumed.phase(), Match.Phase.PICK_COLOUR)
	assert_eq(resumed.awaiting_players(), [0] as Array[int])
	assert_eq(resumed.turn(), played.turn())
	assert_true(resumed.submit(0, Command.pick_colour(BallColour.BLUE)))
	assert_eq(resumed.current_player(), 1)


func test_a_resumed_match_leaves_the_position_it_came_from_alone() -> void:
	var decks: Array[Deck] = _decks()
	var played: Match = Match.create(decks, _secrets(decks), Fixtures.rng(1), 0)
	assert_true(played.submit(1, Command.pick_colour(BallColour.RED)))
	var position: MatchPosition = played.public_view(0).position
	var resumed: Match = Match.resume(position, decks, _secrets(decks), Fixtures.rng(2), Match.Phase.PLACE)
	assert_true(resumed.submit(0, Command.place(Vector2i(2, 2))))
	assert_true(position.board.is_empty(Vector2i(2, 2)))


func test_only_a_place_or_colour_pick_phase_can_be_resumed() -> void:
	var decks: Array[Deck] = _decks()
	var position: MatchPosition = MatchPosition.new(Board.new(), 0)
	assert_null(Match.resume(position, decks, _secrets(decks), Fixtures.rng(1), Match.Phase.OVER))
	assert_push_error("can't resume")
