extends GutTest

# Normal's placement: hide among the rules the opponent can still believe, and
# among those cells keep room for the next ball.

const Fixtures := preload("res://test/helpers/fixtures.gd")

const AI: int = 1
const OPPONENT: int = 0

var _book: RuleBook


func before_each() -> void:
	_book = Fixtures.book()


## A match where the opponent goes first; the AI holds this secret rule and R04
## "Never on the edge" among permissive fakes. The AI hands red, the opponent
## places, and hands the AI red.
func _ai_places(ai_secret_rule: Rule) -> Match:
	var ai_deck: Array[Rule] = [ai_secret_rule, _book.rule("R04")]
	for i: int in range(2, Deck.SIZE):
		ai_deck.append(Fixtures.anywhere(_book, "A%d" % i))
	var opponent_secret: Rule = Fixtures.anywhere(_book, "OT")
	var decks: Array[Deck] = [Fixtures.deck_with(_book, opponent_secret, "O"), Deck.new(ai_deck)]
	var current_match: Match = Match.from_position(MatchPosition.new(Board.new(), OPPONENT), decks,
		[opponent_secret, ai_secret_rule] as Array[Rule], Fixtures.rng(1))
	assert_true(current_match.submit(AI, Command.pick_colour(BallColour.RED)))
	assert_true(current_match.submit(OPPONENT, Command.place(Vector2i(5, 5))))
	assert_true(current_match.submit(OPPONENT, Command.pick_colour(BallColour.RED)))
	return current_match


func _cells(view: PublicView, strategy: PlacementStrategy, seeds: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var exposure: Belief = Belief.of(view, AIController.normal_model(), true)
	for seed_value: int in seeds:
		cells.append(strategy.choose(view, exposure, Fixtures.rng(seed_value)))
	return cells


func test_while_r04_is_believable_it_stays_off_the_edge() -> void:
	var view: PublicView = _ai_places(Fixtures.anywhere(_book, "AT")).public_view(AI)
	for cell: Vector2i in _cells(view, HidingPlacement.new(), 20):
		assert_false(Board.is_on_edge(cell), "an edge cell would rule R04 out: %s" % cell)


func test_once_r04_is_ruled_out_the_edge_is_free_again() -> void:
	var current_match: Match = _ai_places(Fixtures.anywhere(_book, "AT"))
	# The AI's own edge placement has already shown it isn't R04.
	assert_true(current_match.submit(AI, Command.place(Vector2i(0, 0))))
	assert_true(current_match.submit(AI, Command.pick_colour(BallColour.BLUE)))
	assert_true(current_match.submit(OPPONENT, Command.place(Vector2i(5, 4))))
	assert_true(current_match.submit(OPPONENT, Command.pick_colour(BallColour.BLUE)))
	var view: PublicView = current_match.public_view(AI)
	var on_edge: int = 0
	for cell: Vector2i in _cells(view, HidingPlacement.new(), 30):
		if Board.is_on_edge(cell):
			on_edge += 1
	assert_gt(on_edge, 0, "edge cells are back among the choices")
	for cell: Vector2i in _cells(view, PlacementStrategy.new(), 30):
		assert_false(Board.is_on_edge(cell), "the base strategy still counts the dead R04")


func test_room_after_counts_the_worst_colour() -> void:
	# R01 "Never next to the same colour": a red ball in a corner rules out
	# fewer red cells next turn than one in the middle.
	var view: PublicView = _ai_places(_book.rule("R01")).public_view(AI)
	assert_gt(HidingPlacement.room_after(view, Vector2i(0, 0)), HidingPlacement.room_after(view, Vector2i(2, 2)))


func test_among_equally_hidden_cells_it_keeps_the_most_room() -> void:
	# With R01 secret and R04 believable, the inner cells hide best; of those,
	# the ones touching fewest empty cells keep the most room for red next.
	var view: PublicView = _ai_places(_book.rule("R01")).public_view(AI)
	var best_room: int = -1
	for cell: Vector2i in view.own_legal_cells():
		if not Board.is_on_edge(cell):
			best_room = maxi(best_room, HidingPlacement.room_after(view, cell))
	for cell: Vector2i in _cells(view, HidingPlacement.new(), 10):
		assert_eq(HidingPlacement.room_after(view, cell), best_room, "%s" % cell)
