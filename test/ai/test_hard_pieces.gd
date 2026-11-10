extends GutTest

# Hard's pieces: guessing on expected value, colours drawn by softmax over
# their information value, and placement that keeps the secret rule least
# likely in the opponent's eyes.

const Fixtures := preload("res://test/helpers/fixtures.gd")

const AI: int = 1
const OPPONENT: int = 0

var _book: RuleBook


func before_each() -> void:
	_book = Fixtures.book()


## The AI's turn after the opponent's first placement. The AI holds R04 "Never
## on the edge" among permissive rules (its secret rule permissive); the
## opponent holds four permissive rules and R04.
func _match() -> Match:
	var ai_deck: Array[Rule] = [Fixtures.anywhere(_book, "AT"), _book.rule("R04")]
	var opponent_deck: Array[Rule] = [Fixtures.anywhere(_book, "OT"), _book.rule("R04")]
	for i: int in range(2, Deck.SIZE):
		ai_deck.append(Fixtures.anywhere(_book, "A%d" % i))
		opponent_deck.append(Fixtures.anywhere(_book, "O%d" % i))
	var decks: Array[Deck] = [Deck.new(opponent_deck), Deck.new(ai_deck)]
	var current_match: Match = Match.from_position(MatchPosition.new(Board.new(), OPPONENT), decks,
		[opponent_deck[0], ai_deck[0]] as Array[Rule], Fixtures.rng(1))
	assert_true(current_match.submit(AI, Command.pick_colour(BallColour.RED)))
	assert_true(current_match.submit(OPPONENT, Command.place(Vector2i(2, 2))))
	assert_true(current_match.submit(OPPONENT, Command.pick_colour(BallColour.RED)))
	return current_match


func _exposure(view: PublicView) -> Belief:
	return Belief.of(view, AIController.normal_model(), true)


func test_while_hidden_waiting_is_worth_more_than_an_unsure_guess() -> void:
	var view: PublicView = _match().public_view(AI)
	var wait: float = ValueGuessPolicy.value_of_waiting(view, _exposure(view), 0.6)
	assert_gt(wait, 2.0 * 0.6 - 1.0, "a 60% guess is worth less than waiting while the AI is hidden")


func test_one_skip_from_losing_waiting_is_worth_little() -> void:
	var view: PublicView = _match().public_view(AI)
	view.position.skips[AI] = Match.LOSING_SKIP - 1
	var hidden: PublicView = _match().public_view(AI)
	assert_lt(ValueGuessPolicy.value_of_waiting(view, _exposure(view), 0.6),
		ValueGuessPolicy.value_of_waiting(hidden, _exposure(hidden), 0.6))


func test_while_hidden_it_holds_back_on_an_even_belief() -> void:
	# Every opponent rule 1 in 5 likely: guessing is worth 2(0.2) - 1 = -0.6.
	var view: PublicView = _match().public_view(AI)
	var belief: Belief = Belief.of(view, AIController.normal_model())
	assert_null(ValueGuessPolicy.new().choose(belief, _exposure(view), view, Fixtures.rng(1)))


func test_with_one_rule_left_it_guesses() -> void:
	var view: PublicView = _match().public_view(AI)
	var belief: Belief = Belief.of(view, AIController.normal_model())
	view.decks[OPPONENT] = Deck.new([_book.rule("R04")] as Array[Rule])
	belief = Belief.of(view, AIController.normal_model())
	var guess: Rule = ValueGuessPolicy.new().choose(belief, _exposure(view), view, Fixtures.rng(1))
	assert_not_null(guess, "certainty beats waiting")
	assert_eq(guess.id, "R04")


func test_with_playouts_it_holds_back_on_an_even_belief() -> void:
	var view: PublicView = _match().public_view(AI)
	var belief: Belief = Belief.of(view, AIController.normal_model())
	assert_null(RolloutGuessPolicy.new(4).choose(belief, _exposure(view), view, Fixtures.rng(1)),
		"a 1-in-5 guess is worth -0.6; playing on from turn 2 is worth more")


func test_with_playouts_and_one_rule_left_it_guesses_without_playing_out() -> void:
	var view: PublicView = _match().public_view(AI)
	view.decks[OPPONENT] = Deck.new([_book.rule("R04")] as Array[Rule])
	var belief: Belief = Belief.of(view, AIController.normal_model())
	var guess: Rule = RolloutGuessPolicy.new(0).choose(belief, _exposure(view), view, Fixtures.rng(1))
	assert_not_null(guess)
	assert_eq(guess.id, "R04")


func test_playouts_follow_the_seed() -> void:
	var view: PublicView = _match().public_view(AI)
	var first: float = RolloutGuessPolicy.new(3).value_of_waiting(view, Fixtures.rng(7))
	var again: float = RolloutGuessPolicy.new(3).value_of_waiting(view, Fixtures.rng(7))
	assert_eq(first, again)
	assert_between(first, -1.0, 1.0)


func test_after_breaking_a_fake_it_protects_the_others() -> void:
	# The AI's own edge placement broke R04: from then on, an opponent knows
	# R04 isn't its rule, so the AI no longer stays off the edge for it.
	var current_match: Match = _match()
	assert_true(current_match.submit(AI, Command.place(Vector2i(0, 0))))
	assert_true(current_match.submit(AI, Command.pick_colour(BallColour.BLUE)))
	assert_true(current_match.submit(OPPONENT, Command.place(Vector2i(5, 4))))
	assert_true(current_match.submit(OPPONENT, Command.pick_colour(BallColour.BLUE)))
	var view: PublicView = current_match.public_view(AI)
	var exposure: Belief = _exposure(view)
	assert_eq(exposure.probability("R04"), 0.0, "the broken fake is out for good")
	var on_edge: int = 0
	for seed_value: int in 30:
		if Board.is_on_edge(ExposurePlacement.new(AIController.normal_model()).choose(view, exposure, Fixtures.rng(seed_value))):
			on_edge += 1
	assert_gt(on_edge, 0, "edge cells are no longer avoided for the dead fake")


func test_softmax_colours_are_drawn_not_always_the_best() -> void:
	# At precision 0 every colour is equally likely, so all four come up.
	var view: PublicView = _match().public_view(AI)
	var belief: Belief = Belief.of(view, AIController.normal_model())
	var picked: Dictionary[String, int] = {}
	for seed_value: int in 60:
		var colour: String = SoftmaxColourPick.new(AIController.normal_model(), 0.0).choose(view, belief, Fixtures.rng(seed_value))
		picked[colour] = picked.get(colour, 0) + 1
	assert_eq(picked.size(), BallColour.ALL.size(), "precision 0 draws every colour")


func test_exposure_placement_keeps_r04_believable() -> void:
	# An edge cell would show the opponent the AI's R04 is not its rule, making
	# its secret rule likelier to them; inner cells keep R04 in play.
	var view: PublicView = _match().public_view(AI)
	var exposure: Belief = _exposure(view)
	for seed_value: int in 20:
		var cell: Vector2i = ExposurePlacement.new(AIController.normal_model()).choose(view, exposure, Fixtures.rng(seed_value))
		assert_false(Board.is_on_edge(cell), "%s" % cell)


func test_hard_is_not_playable_yet() -> void:
	assert_false(AILevel.is_built(AILevel.Level.HARD), "it must beat Normal 60% first (now about 55%)")
	assert_not_null(AIController.for_level(AILevel.Level.HARD, Fixtures.rng(1)), "but it can be built for measurement")
