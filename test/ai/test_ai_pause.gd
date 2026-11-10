extends GutTest

# The AI's thinking pause: short when the choice was easy, longer the closer
# it was, longest for a guess made or held back right at its threshold.

const Fixtures := preload("res://test/helpers/fixtures.gd")

const AI: int = 1
const OPPONENT: int = 0

var _book: RuleBook


func before_each() -> void:
	_book = Fixtures.book()


## The AI's turn after the opponent's first placement; the opponent's deck is
## their secret rule "OT" and four more permissive rules, all equally likely.
func _ai_turn() -> PublicView:
	var opponent_secret: Rule = Fixtures.anywhere(_book, "OT")
	var ai_secret: Rule = Fixtures.anywhere(_book, "AT")
	var decks: Array[Deck] = [Fixtures.deck_with(_book, opponent_secret, "O"), Fixtures.deck_with(_book, ai_secret, "A")]
	var current_match: Match = Match.from_position(MatchPosition.new(Board.new(), OPPONENT), decks,
		[opponent_secret, ai_secret] as Array[Rule], Fixtures.rng(1))
	assert_true(current_match.submit(AI, Command.pick_colour(BallColour.RED)))
	assert_true(current_match.submit(OPPONENT, Command.place(Vector2i(2, 2))))
	assert_true(current_match.submit(OPPONENT, Command.pick_colour(BallColour.RED)))
	return current_match.public_view(AI)


func _pause_after(ai: AIController, view: PublicView) -> float:
	await ai.decide(view)
	return ai.pause_seconds(Fixtures.rng(1))


func test_a_clear_placement_is_quick() -> void:
	# Each rule 1 in 5: far below Normal's 0.95, so holding off is clear.
	var seconds: float = await _pause_after(AIController.new(Fixtures.rng(1)), _ai_turn())
	assert_lt(seconds, 1.2)
	assert_gte(seconds, AIController.SHORTEST_PAUSE)


func test_a_guess_held_back_right_at_its_threshold_takes_longest() -> void:
	# A threshold just above 1 in 5: the AI only just holds back.
	var seconds: float = await _pause_after(AIController.new(Fixtures.rng(1), GuessPolicy.new(0.22)), _ai_turn())
	assert_gt(seconds, AIController.ROUTINE_PAUSE, "longer than any routine move")
	assert_lte(seconds, AIController.LONGEST_PAUSE)


func test_a_pause_never_leaves_its_bounds() -> void:
	var ai: AIController = AIController.new(Fixtures.rng(1), GuessPolicy.new(0.2))
	await ai.decide(_ai_turn())
	for seed_value: int in 50:
		assert_between(ai.pause_seconds(Fixtures.rng(seed_value)), AIController.SHORTEST_PAUSE, AIController.LONGEST_PAUSE)
