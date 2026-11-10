extends GutTest

# Normal's guess threshold: near-certainty while its own rule is well hidden,
# lower the more exposed it is, and at its lowest one skip from losing.

const Fixtures := preload("res://test/helpers/fixtures.gd")

const AI: int = 1
const OPPONENT: int = 0

var _book: RuleBook


func before_each() -> void:
	_book = Fixtures.book()


## A match where the AI holds R04 among permissive rules, its secret rule "AT"
## permissive; the opponent's deck is permissive.
func _match() -> Match:
	var ai_deck: Array[Rule] = [Fixtures.anywhere(_book, "AT"), _book.rule("R04")]
	for i: int in range(2, Deck.SIZE):
		ai_deck.append(Fixtures.anywhere(_book, "A%d" % i))
	var opponent_secret: Rule = Fixtures.anywhere(_book, "OT")
	var decks: Array[Deck] = [Fixtures.deck_with(_book, opponent_secret, "O"), Deck.new(ai_deck)]
	var secret_rules: Array[Rule] = [opponent_secret, ai_deck[0]]
	return Match.from_position(MatchPosition.new(Board.new(), OPPONENT), decks, secret_rules, Fixtures.rng(1))


func _threshold(view: PublicView) -> float:
	return DangerGuessPolicy.new().threshold(view, Belief.of(view, HiderModel.new(), true))


func test_while_hidden_it_waits_for_near_certainty() -> void:
	assert_almost_eq(_threshold(_match().public_view(AI)), DangerGuessPolicy.SAFE, 1e-9)


func test_more_exposed_it_settles_for_less() -> void:
	var current_match: Match = _match()
	assert_true(current_match.submit(AI, Command.pick_colour(BallColour.RED)))
	assert_true(current_match.submit(OPPONENT, Command.place(Vector2i(2, 2))))
	assert_true(current_match.submit(OPPONENT, Command.pick_colour(BallColour.RED)))
	# The AI's edge placement shows the opponent its R04 is not its rule.
	assert_true(current_match.submit(AI, Command.place(Vector2i(0, 0))))
	var threshold: float = _threshold(current_match.public_view(AI))
	assert_lt(threshold, DangerGuessPolicy.SAFE)
	assert_gt(threshold, DangerGuessPolicy.DESPERATE)


func test_one_skip_from_losing_it_is_at_its_lowest() -> void:
	var view: PublicView = _match().public_view(AI)
	view.position.skips[AI] = Match.LOSING_SKIP - 1
	assert_almost_eq(_threshold(view), DangerGuessPolicy.DESPERATE, 1e-9)


func test_the_base_policy_keeps_its_fixed_threshold() -> void:
	var view: PublicView = _match().public_view(AI)
	var exposure: Belief = Belief.of(view, HiderModel.new(), true)
	assert_eq(GuessPolicy.new(0.7).threshold(view, exposure), 0.7)
	assert_null(GuessPolicy.new(INF).choose(Belief.of(view, HiderModel.new()), exposure, view, Fixtures.rng(1)), "INF never guesses")
