extends GutTest

# Easy: learns slowly, places anywhere legal, picks colours loosely, and only
# guesses when nearly sure; Normal beats it clearly.

const Fixtures := preload("res://test/helpers/fixtures.gd")

const AI: int = 1
const OPPONENT: int = 0

var _book: RuleBook


func before_each() -> void:
	_book = Fixtures.book()


## The AI's turn after the opponent placed on an inner cell. The AI holds R04
## "Never on the edge" among permissive rules (its secret rule permissive);
## the opponent holds R04 and four permissive rules (their secret "OT").
func _ai_turn() -> PublicView:
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
	return current_match.public_view(AI)


func test_easy_is_a_built_level() -> void:
	assert_true(AILevel.is_built(AILevel.Level.EASY))
	assert_not_null(AIController.for_level(AILevel.Level.EASY, Fixtures.rng(1)))


func test_easy_places_anywhere_legal_giving_its_rule_away() -> void:
	# Normal stays off the edge so R04 stays believable; Easy doesn't care.
	var view: PublicView = _ai_turn()
	var on_edge: int = 0
	for seed_value: int in 30:
		var command: Command = await AIController.for_level(AILevel.Level.EASY, Fixtures.rng(seed_value)).decide(view)
		assert_eq(command.type, Command.Type.PLACE)
		if Board.is_on_edge(command.cell):
			on_edge += 1
	assert_gt(on_edge, 0)


func test_easy_learns_more_slowly_than_normal() -> void:
	var view: PublicView = _ai_turn()
	var easy: Belief = Belief.of(view, AIController.easy_model())
	var normal: Belief = Belief.of(view, AIController.normal_model())
	assert_gt(easy.probability("R04"), 1.0 / Deck.SIZE, "the inner placement still counts a little")
	assert_lt(easy.probability("R04") - 0.2, normal.probability("R04") - 0.2 + 0.05)
	assert_lt(easy.probability("R04"), 0.3)


func test_a_loose_pick_is_sometimes_considered_and_otherwise_any_colour() -> void:
	var view: PublicView = _ai_turn()
	var belief: Belief = Belief.of(view, AIController.easy_model())
	var colours: Array[String] = []
	for seed_value: int in 40:
		var colour: String = LooseColourPick.new(0.0).choose(view, belief, Fixtures.rng(seed_value))
		if not colours.has(colour):
			colours.append(colour)
	assert_eq(colours.size(), BallColour.ALL.size(), "with no focus, every colour comes up")
	var base: ColourPickStrategy = ColourPickStrategy.new()
	var best_score: float = -INF
	for colour: String in BallColour.ALL:
		best_score = maxf(best_score, base.score(view, belief.alive(), colour))
	for seed_value: int in 10:
		var colour: String = LooseColourPick.new(1.0).choose(view, belief, Fixtures.rng(seed_value))
		assert_almost_eq(base.score(view, belief.alive(), colour), best_score, 1e-9, "full focus is a considered pick")


func test_easy_waits_until_nearly_sure() -> void:
	var view: PublicView = _ai_turn()
	view.position.skips[AI] = Match.LOSING_SKIP - 1
	var command: Command = await AIController.for_level(AILevel.Level.EASY, Fixtures.rng(1)).decide(view)
	assert_ne(command.type, Command.Type.GUESS, "no gamble even one skip from losing")


func test_normal_beats_easy_clearly() -> void:
	# Measured over 200 seeded matches: 181-19.
	var normal_wins: int = 0
	var easy_wins: int = 0
	for seed_value: int in 30:
		var rng: RandomNumberGenerator = Fixtures.rng(seed_value)
		var decks: Array[Deck] = [Deck.draw(_book, rng), Deck.draw(_book, rng)]
		var secret_rules: Array[Rule] = [decks[0].random_rule(rng), decks[1].random_rule(rng)]
		var normal_seat: int = seed_value % 2
		var ais: Array[AIController] = []
		for player: int in Players.COUNT:
			var level: AILevel.Level = AILevel.Level.NORMAL if player == normal_seat else AILevel.Level.EASY
			ais.append(AIController.for_level(level, Fixtures.rng(seed_value + 100 * player)))
		var current_match: Match = Match.create(decks, secret_rules, rng)
		assert_true(Harness.play_out(current_match, ais), "seed %d" % seed_value)
		if current_match.result().winner == normal_seat:
			normal_wins += 1
		elif current_match.result().winner != Players.NONE:
			easy_wins += 1
	assert_gt(normal_wins, 2 * easy_wins, "Normal %d, Easy %d" % [normal_wins, easy_wins])
