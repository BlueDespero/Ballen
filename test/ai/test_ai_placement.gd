extends GutTest

# The AI seam for placement: given a PublicView on its turn to place, check
# which legal cell the AI chooses. Views come from real matches.

const Fixtures := preload("res://test/helpers/fixtures.gd")

## The AI's player in these matches; it goes first.
const AI: int = 0
const OPPONENT: int = 1
## A template whose rules allow no cell.
const NOWHERE_TEMPLATE: Dictionary = {"blanks": {}, "tree": {"part": "count_at_most", "n": 0, "of": {"part": "target"}}}

var _book: RuleBook


func before_each() -> void:
	_book = Fixtures.book()
	_book.add_template("nowhere", NOWHERE_TEMPLATE)


func _nowhere(rule_id: String) -> Rule:
	return _book.make_rule({"id": rule_id, "text": "Nowhere (%s)" % rule_id, "template": "nowhere", "values": {}})


## A new match where the AI holds this deck, its first rule true, and the
## opponent has just handed it red for its first ball.
func _ai_to_place(ai_deck: Array[Rule]) -> Match:
	var opponent_true_rule: Rule = Fixtures.anywhere(_book, "BT")
	var decks: Array[Deck] = [Deck.new(ai_deck), Fixtures.deck_with(_book, opponent_true_rule, "B")]
	var true_rules: Array[Rule] = [ai_deck[0], opponent_true_rule]
	var current_match: Match = Match.from_position(MatchPosition.from_board(Board.new(), AI), decks, true_rules, Fixtures.rng(1))
	assert_true(current_match.submit(OPPONENT, Command.pick_colour(BallColour.RED)))
	return current_match


func _placed_cells(ai_deck: Array[Rule], seeds: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var view: PublicView = _ai_to_place(ai_deck).public_view(AI)
	for seed_value: int in seeds:
		var command: Command = await AIController.new(Fixtures.rng(seed_value)).decide(view)
		assert_eq(command.type, Command.Type.PLACE)
		cells.append(command.cell)
	return cells


func test_the_ai_places_where_the_most_of_its_rules_allow() -> void:
	# Every cell is legal under the true rule "AT"; inner cells also satisfy
	# R04, and no cell satisfies N2..N4. Inner cells satisfy 2 rules, edge
	# cells 1.
	var deck: Array[Rule] = [Fixtures.anywhere(_book, "AT"), _book.rule("R04"), _nowhere("N2"), _nowhere("N3"), _nowhere("N4")]
	for cell: Vector2i in await _placed_cells(deck, 20):
		assert_false(Board.is_on_edge(cell), "%s is on the edge" % cell)


func test_the_ai_breaks_ties_between_its_best_cells_at_random() -> void:
	var deck: Array[Rule] = [Fixtures.anywhere(_book, "AT"), _book.rule("R04"), _nowhere("N2"), _nowhere("N3"), _nowhere("N4")]
	var distinct: Array[Vector2i] = []
	for cell: Vector2i in await _placed_cells(deck, 20):
		if not distinct.has(cell):
			distinct.append(cell)
	assert_gt(distinct.size(), 4, "20 seeds spread over the 16 inner cells")
