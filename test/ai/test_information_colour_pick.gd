extends GutTest

# Normal's colour pick: the colour whose next opponent turn is expected to
# teach the AI the most about their secret rule, plus a bonus for a skip.

const Fixtures := preload("res://test/helpers/fixtures.gd")

const AI: int = 1
const OPPONENT: int = 0

var _book: RuleBook


func before_each() -> void:
	_book = Fixtures.book()


## A match where the AI picks the opponent's first colour. The opponent holds
## R02 "Red only next to blue" and four permissive rules (their secret rule
## "OT" among them). The board's only blue ball sits in a corner with all its
## neighbours taken, so R02 allows no red cell: red is the only colour that
## tells the rules apart.
func _match() -> Match:
	var opponent_deck: Array[Rule] = [Fixtures.anywhere(_book, "OT"), _book.rule("R02")]
	for i: int in range(2, Deck.SIZE):
		opponent_deck.append(Fixtures.anywhere(_book, "O%d" % i))
	var ai_secret_rule: Rule = Fixtures.anywhere(_book, "AT")
	var decks: Array[Deck] = [Deck.new(opponent_deck), Fixtures.deck_with(_book, ai_secret_rule, "A")]
	var secret_rules: Array[Rule] = [opponent_deck[0], ai_secret_rule]
	var board: Board = Board.parse(["by....", "yy....", "......", "......", "......", "......"])
	return Match.from_position(MatchPosition.new(board, OPPONENT), decks, secret_rules, Fixtures.rng(1))


func _view() -> PublicView:
	return _match().public_view(AI)


func _pick() -> InformationColourPick:
	return InformationColourPick.new(AIController.normal_model())


func test_a_colour_every_rule_treats_alike_teaches_nothing() -> void:
	var view: PublicView = _view()
	var belief: Belief = Belief.of(view, AIController.normal_model())
	for colour: String in [BallColour.YELLOW, BallColour.BLUE, BallColour.GREEN]:
		assert_almost_eq(_pick().value(view, belief, colour), 0.0, 1e-9, colour)


func test_the_colour_that_tells_rules_apart_is_worth_the_most() -> void:
	var view: PublicView = _view()
	var belief: Belief = Belief.of(view, AIController.normal_model())
	assert_gt(_pick().value(view, belief, BallColour.RED), 0.5, "red: a skip would prove R02, a placement rule it out")
	for seed_value: int in 10:
		assert_eq(_pick().choose(view, belief, Fixtures.rng(seed_value)), BallColour.RED, "seed %d" % seed_value)


func test_a_skip_is_worth_more_the_closer_it_brings_the_opponent_to_losing() -> void:
	var view: PublicView = _view()
	var belief: Belief = Belief.of(view, AIController.normal_model())
	var values: Array[float] = []
	for skips: int in Match.LOSING_SKIP:
		view.position.skips[OPPONENT] = skips
		values.append(_pick().value(view, belief, BallColour.RED))
	assert_lt(values[0], values[1])
	assert_lt(values[1], values[2])
	assert_gt(values[2], 1.0 + values[1], "a third skip wins the match")


func test_a_ruled_out_rule_no_longer_counts() -> void:
	# A red placement with blue on the board but not beside it rules R02 out;
	# then red tells nothing apart any more.
	var current_match: Match = _match()
	assert_true(current_match.submit(AI, Command.pick_colour(BallColour.RED)))
	assert_true(current_match.submit(OPPONENT, Command.place(Vector2i(5, 5))))
	assert_true(current_match.submit(OPPONENT, Command.pick_colour(BallColour.BLUE)))
	assert_true(current_match.submit(AI, Command.place(Vector2i(4, 4))))
	var view: PublicView = current_match.public_view(AI)
	var belief: Belief = Belief.of(view, AIController.normal_model())
	assert_eq(belief.probability("R02"), 0.0)
	assert_almost_eq(_pick().value(view, belief, BallColour.RED), 0.0, 1e-9)
