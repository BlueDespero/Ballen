extends GutTest

# The AI seam for colour picks: given a PublicView where the AI picks the
# opponent's colour, check which colour it chooses. Views come from real
# matches.

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


## A match where the opponent holds this deck, its first rule true, and the AI
## holds a permissive deck.
func _match(position: MatchPosition, opponent_deck: Array[Rule]) -> Match:
	var ai_true_rule: Rule = Fixtures.anywhere(_book, "AT")
	var decks: Array[Deck] = [Deck.new(opponent_deck), Fixtures.deck_with(_book, ai_true_rule, "A")]
	var true_rules: Array[Rule] = [opponent_deck[0], ai_true_rule]
	return Match.from_position(position, decks, true_rules, Fixtures.rng(1))


func _colours_picked(view: PublicView, seeds: int) -> Array[String]:
	var colours: Array[String] = []
	for seed_value: int in seeds:
		var command: Command = await AIController.new(Fixtures.rng(seed_value)).decide(view)
		assert_eq(command.type, Command.Type.PICK_COLOUR)
		colours.append(command.colour)
	return colours


func test_the_ais_first_pick_with_no_information_is_a_random_colour() -> void:
	var deck: Array[Rule] = [_book.rule("R01"), _book.rule("R03"), _book.rule("R04"), _book.rule("R05"), _book.rule("R07")]
	var view: PublicView = _match(MatchPosition.from_board(Board.new(), OPPONENT), deck).public_view(AI)
	assert_eq(view.phase, Match.Phase.FIRST_COLOUR)
	var distinct: Array[String] = []
	for colour: String in await _colours_picked(view, 20):
		if not distinct.has(colour):
			distinct.append(colour)
	assert_gt(distinct.size(), 1, "different seeds pick different colours")


func test_the_ai_picks_the_colour_expected_to_rule_out_the_most_candidates() -> void:
	# Candidates "OT" (allows every cell) and R01 (never next to the same
	# colour): the opponent's red ball at (2, 2) rules out N2..N4. After the
	# AI's blue ball at (5, 5), the opponent places uniformly on 34 empty
	# cells. Red: if OT is true, 8 of them (next to the red ball) rule R01
	# out; if R01 is true, nothing is ruled out: 4/34 expected. Blue: 3 cells
	# next to the blue ball: 3/68. Yellow, green: 0.
	var deck: Array[Rule] = [Fixtures.anywhere(_book, "OT"), _book.rule("R01"), _nowhere("N2"), _nowhere("N3"), _nowhere("N4")]
	var current_match: Match = _match(MatchPosition.from_board(Board.new(), OPPONENT), deck)
	assert_true(current_match.submit(AI, Command.pick_colour(BallColour.RED)))
	assert_true(current_match.submit(OPPONENT, Command.place(Vector2i(2, 2))))
	assert_true(current_match.submit(OPPONENT, Command.pick_colour(BallColour.BLUE)))
	assert_true(current_match.submit(AI, Command.place(Vector2i(5, 5))))
	for colour: String in await _colours_picked(current_match.public_view(AI), 20):
		assert_eq(colour, BallColour.RED)


func test_the_ai_counts_what_a_skip_would_rule_out() -> void:
	# Candidates "OT" (allows every cell), R01 (never next to the same colour)
	# and R04 (never on the edge); the opponent's yellow ball at (4, 4) rules
	# out N3 and N4. After the AI's yellow ball at (5, 5), four cells are
	# empty: edge cells (1, 0) and (3, 0), inner cells (1, 1) and (2, 1).
	# All four are next to blue; all but (3, 0) are next to red.
	# Blue: OT rules out R01, and R04 half the time (1.5); under R01 the
	# opponent skips, which rules out OT and R04 (2); R04 rules out R01 (1).
	# Expected 4.5 / 3 = 1.5.
	# Red: OT 0.75 + 0.5; R01 only allows (3, 0), ruling out R04 (1); R04
	# rules out R01 (1). Expected 3.25 / 3, about 1.08: more than blue's 2.5 / 3
	# if the skip counted for nothing.
	var position: MatchPosition = MatchPosition.from_board(Board.parse([
		"R.b.bG",
		"R..bbg",
		"RRRRyg",
		"gygGBb",
		"ygygYg",
		"gygbr.",
	]), OPPONENT)
	position.turn = 2
	position.colour = BallColour.YELLOW
	position.history = [
		HistoryEntry.colour_pick(AI, BallColour.YELLOW),
		HistoryEntry.placement(OPPONENT, Vector2i(4, 4), BallColour.YELLOW),
		HistoryEntry.colour_pick(OPPONENT, BallColour.YELLOW),
	]
	var deck: Array[Rule] = [Fixtures.anywhere(_book, "OT"), _book.rule("R01"), _book.rule("R04"), _nowhere("N3"), _nowhere("N4")]
	var current_match: Match = _match(position, deck)
	assert_true(current_match.submit(AI, Command.place(Vector2i(5, 5))))
	assert_eq(Deduction.candidates(current_match.public_view(AI)).size(), 3, "N3 and N4 ruled out")
	for colour: String in await _colours_picked(current_match.public_view(AI), 20):
		assert_eq(colour, BallColour.BLUE)


class AlwaysGreen:
	extends ColourPickStrategy

	func choose(_view: PublicView, _candidates: Array[Rule], _rng: RandomNumberGenerator) -> String:
		return BallColour.GREEN


func test_a_swapped_colour_pick_strategy_changes_the_ais_pick() -> void:
	var deck: Array[Rule] = [Fixtures.anywhere(_book, "OT"), _book.rule("R01"), _nowhere("N2"), _nowhere("N3"), _nowhere("N4")]
	var view: PublicView = _match(MatchPosition.from_board(Board.new(), OPPONENT), deck).public_view(AI)
	var ai: AIController = AIController.new(Fixtures.rng(1), GuessPolicy.new(), AlwaysGreen.new())
	var command: Command = await ai.decide(view)
	assert_eq(command.colour, BallColour.GREEN)
