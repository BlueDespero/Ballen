extends GutTest

# The AI seam for guessing: given a PublicView, check when the AI names the
# opponent's true rule. Views come from real matches.

const Fixtures := preload("res://test/helpers/fixtures.gd")

## The AI's player in these matches; the opponent, player 0, goes first.
const AI: int = 1
const OPPONENT: int = 0
## A template whose rules allow no cell: any placement rules them out.
const NOWHERE_TEMPLATE: Dictionary = {"blanks": {}, "tree": {"part": "count_at_most", "n": 0, "of": {"part": "target"}}}

var _book: RuleBook


func before_each() -> void:
	_book = Fixtures.book()
	_book.add_template("nowhere", NOWHERE_TEMPLATE)


func _nowhere(rule_id: String) -> Rule:
	return _book.make_rule({"id": rule_id, "text": "Nowhere (%s)" % rule_id, "template": "nowhere", "values": {}})


## A match where the opponent has placed one ball and handed the AI red: the
## AI's turn starts. The opponent's true rule "OT" and `permissive` other rules
## allow every cell; the rest of their deck allows none, so that placement
## ruled them out.
func _ai_turn(permissive: int) -> Match:
	var opponent_deck: Array[Rule] = [Fixtures.anywhere(_book, "OT")]
	for i: int in range(1, Deck.SIZE):
		opponent_deck.append(Fixtures.anywhere(_book, "O%d" % i) if i <= permissive else _nowhere("N%d" % i))
	var ai_true_rule: Rule = Fixtures.anywhere(_book, "AT")
	var decks: Array[Deck] = [Deck.new(opponent_deck), Fixtures.deck_with(_book, ai_true_rule, "A")]
	var true_rules: Array[Rule] = [opponent_deck[0], ai_true_rule]
	var current_match: Match = Match.from_position(MatchPosition.from_board(Board.new(), OPPONENT), decks, true_rules, Fixtures.rng(1))
	assert_true(current_match.submit(AI, Command.pick_colour(BallColour.RED)))
	assert_true(current_match.submit(OPPONENT, Command.place(Vector2i(2, 2))))
	assert_true(current_match.submit(OPPONENT, Command.pick_colour(BallColour.RED)))
	return current_match


func test_the_ai_guesses_at_the_start_of_its_turn_when_one_candidate_remains() -> void:
	var current_match: Match = _ai_turn(0)
	var command: Command = await AIController.new(Fixtures.rng(1)).decide(current_match.public_view(AI))
	assert_eq(command.type, Command.Type.GUESS)
	assert_eq(command.rule_id, "OT")
	assert_true(current_match.submit(AI, command))
	assert_eq(current_match.result().winner, AI)
	assert_eq(current_match.result().reason, MatchResult.Reason.RIGHT_GUESS)


func test_the_ai_guesses_after_it_places_when_one_candidate_remains() -> void:
	var current_match: Match = _ai_turn(0)
	assert_true(current_match.submit(AI, Command.place(Vector2i(4, 4))))
	var command: Command = await AIController.new(Fixtures.rng(1)).decide(current_match.public_view(AI))
	assert_eq(command.type, Command.Type.GUESS)
	assert_eq(command.rule_id, "OT")


func test_with_two_candidates_left_the_ai_does_not_guess() -> void:
	var current_match: Match = _ai_turn(1)
	var ai: AIController = AIController.new(Fixtures.rng(1))
	var command: Command = await ai.decide(current_match.public_view(AI))
	assert_eq(command.type, Command.Type.PLACE)
	assert_true(current_match.submit(AI, command))
	command = await ai.decide(current_match.public_view(AI))
	assert_eq(command.type, Command.Type.PICK_COLOUR)


func test_a_swapped_guess_policy_changes_when_the_ai_guesses() -> void:
	var current_match: Match = _ai_turn(1)
	var command: Command = await AIController.new(Fixtures.rng(1), GuessPolicy.new(0.5)).decide(current_match.public_view(AI))
	assert_eq(command.type, Command.Type.GUESS, "confidence 1/2 reaches a threshold of 0.5")
	assert_has(["OT", "O1"], command.rule_id)


func test_over_seeded_ai_matches_through_the_driver_every_guess_is_right() -> void:
	var right_guesses: int = 0
	for seed_value: int in 30:
		var rng: RandomNumberGenerator = Fixtures.rng(seed_value)
		var decks: Array[Deck] = [Deck.draw(_book, rng), Deck.draw(_book, rng)]
		var true_rules: Array[Rule] = []
		for deck: Deck in decks:
			true_rules.append(deck.rules[rng.randi_range(0, Deck.SIZE - 1)])
		var current_match: Match = Match.create(decks, true_rules, rng)
		var controllers: Array[Controller] = [AIController.new(Fixtures.rng(seed_value + 100)), AIController.new(Fixtures.rng(seed_value + 200))]
		await MatchDriver.new(current_match, controllers, [], rng, func(_seconds: float) -> void: pass).run()
		assert_eq(current_match.phase(), Match.Phase.OVER, "seed %d" % seed_value)
		assert_ne(current_match.result().reason, MatchResult.Reason.WRONG_GUESS, "seed %d" % seed_value)
		if current_match.result().reason == MatchResult.Reason.RIGHT_GUESS:
			right_guesses += 1
	assert_gt(right_guesses, 0, "some matches end on a guess")
