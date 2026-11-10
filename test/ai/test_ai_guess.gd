extends GutTest

# The AI seam for guessing: given a PublicView, check when the AI names the
# opponent's secret rule. Views come from real matches.

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
## AI's turn starts. The opponent's secret rule "OT" and `permissive` other rules
## allow every cell; the rest of their deck allows none, so that placement
## ruled them out.
func _ai_turn(permissive: int) -> Match:
	var opponent_deck: Array[Rule] = [Fixtures.anywhere(_book, "OT")]
	for i: int in range(1, Deck.SIZE):
		opponent_deck.append(Fixtures.anywhere(_book, "O%d" % i) if i <= permissive else _nowhere("N%d" % i))
	var ai_secret_rule: Rule = Fixtures.anywhere(_book, "AT")
	var decks: Array[Deck] = [Deck.new(opponent_deck), Fixtures.deck_with(_book, ai_secret_rule, "A")]
	var secret_rules: Array[Rule] = [opponent_deck[0], ai_secret_rule]
	var current_match: Match = Match.from_position(MatchPosition.new(Board.new(), OPPONENT), decks, secret_rules, Fixtures.rng(1))
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


func test_over_seeded_ai_matches_guesses_only_name_rules_still_possible() -> void:
	var guesses: int = 0
	for seed_value: int in 30:
		var rng: RandomNumberGenerator = Fixtures.rng(seed_value)
		var decks: Array[Deck] = [Deck.draw(_book, rng), Deck.draw(_book, rng)]
		var secret_rules: Array[Rule] = [decks[0].random_rule(rng), decks[1].random_rule(rng)]
		var current_match: Match = Match.create(decks, secret_rules, rng)
		var ais: Array[AIController] = [AIController.new(Fixtures.rng(seed_value + 100)), AIController.new(Fixtures.rng(seed_value + 200))]
		while current_match.phase() != Match.Phase.OVER:
			var player: int = current_match.awaiting_players()[0]
			var view: PublicView = current_match.public_view(player)
			var command: Command = await ais[player].decide(view)
			if command.type == Command.Type.GUESS:
				var live: Array[String] = []
				for rule: Rule in Deduction.candidates(view):
					live.append(rule.id)
				assert_has(live, command.rule_id, "seed %d: never a rule the moves ruled out" % seed_value)
				guesses += 1
			assert_true(current_match.submit(player, command), "seed %d" % seed_value)
	assert_gt(guesses, 0, "some matches end on a guess")


func test_reading_soft_evidence_beats_waiting_for_certainty() -> void:
	# Normal against an AI that, like the first AI, guesses only once one rule
	# is left; seats swap between seeds. Measured over 200 matches: about 65%.
	var wins: int = 0
	var losses: int = 0
	for seed_value: int in 40:
		var rng: RandomNumberGenerator = Fixtures.rng(seed_value)
		var decks: Array[Deck] = [Deck.draw(_book, rng), Deck.draw(_book, rng)]
		var secret_rules: Array[Rule] = [decks[0].random_rule(rng), decks[1].random_rule(rng)]
		var normal_seat: int = seed_value % 2
		var ais: Array[AIController] = []
		for player: int in Players.COUNT:
			ais.append(AIController.for_level(AILevel.Level.NORMAL, Fixtures.rng(seed_value + 100 * player)) if player == normal_seat
				else AIController.new(Fixtures.rng(seed_value + 100 * player), GuessPolicy.new(), ColourPickStrategy.new(), OpponentModel.new()))
		var current_match: Match = Match.create(decks, secret_rules, rng)
		assert_true(Harness.play_out(current_match, ais), "seed %d" % seed_value)
		if current_match.result().winner == normal_seat:
			wins += 1
		elif current_match.result().winner != Players.NONE:
			losses += 1
	assert_gt(wins, losses, "Normal wins %d, loses %d" % [wins, losses])
