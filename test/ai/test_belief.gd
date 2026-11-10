extends GutTest

# The AI's belief about the opponent's secret rule: hard evidence rules rules
# out for good, soft evidence weighs the rest by the AI's model of the player.
# Views come from real matches.

const Fixtures := preload("res://test/helpers/fixtures.gd")

## The AI's player in these matches; the opponent, player 0, goes first.
const AI: int = 1
const OPPONENT: int = 0
## R04 "Never on the edge" allows the 16 inner cells of an empty board; the
## permissive rules allow all 36.
const INNER_CELLS: int = 16
const ALL_CELLS: int = 36

var _book: RuleBook


func before_each() -> void:
	_book = Fixtures.book()


## A match on an empty board where the opponent holds R04 and four permissive
## rules (their secret rule "OT" among them) and the AI a permissive deck.
func _match() -> Match:
	var opponent_deck: Array[Rule] = [Fixtures.anywhere(_book, "OT"), _book.rule("R04")]
	for i: int in range(2, Deck.SIZE):
		opponent_deck.append(Fixtures.anywhere(_book, "O%d" % i))
	var ai_deck: Array[Rule] = [Fixtures.anywhere(_book, "AT"), _book.rule("R04")]
	for i: int in range(2, Deck.SIZE):
		ai_deck.append(Fixtures.anywhere(_book, "A%d" % i))
	var decks: Array[Deck] = [Deck.new(opponent_deck), Deck.new(ai_deck)]
	var secret_rules: Array[Rule] = [opponent_deck[0], ai_deck[0]]
	return Match.from_position(MatchPosition.new(Board.new(), OPPONENT), decks, secret_rules, Fixtures.rng(1))


## The AI hands the opponent red and the opponent places it on cell.
func _opponent_places(cell: Vector2i) -> Match:
	var current_match: Match = _match()
	assert_true(current_match.submit(AI, Command.pick_colour(BallColour.RED)))
	assert_true(current_match.submit(OPPONENT, Command.place(cell)))
	return current_match


func test_with_nothing_seen_every_rule_is_equally_likely() -> void:
	var belief: Belief = Belief.of(_match().public_view(AI), OpponentModel.new())
	for chance: float in belief.probabilities().values():
		assert_almost_eq(chance, 1.0 / Deck.SIZE, 1e-9)
	assert_almost_eq(belief.entropy(), log(Deck.SIZE) / log(2.0), 1e-9, "fully hidden: log2(5) bits")


func test_a_placement_favours_the_rule_that_allows_fewer_cells() -> void:
	# The size principle: a random placer picks an inner cell 1/16 of the time
	# under R04, 1/36 under a rule allowing every cell.
	var belief: Belief = Belief.of(_opponent_places(Vector2i(2, 2)).public_view(AI), OpponentModel.new())
	var ratio: float = belief.probability("R04") / belief.probability("OT")
	assert_almost_eq(ratio, float(ALL_CELLS) / INNER_CELLS, 1e-6)
	var total: float = 0.0
	for chance: float in belief.probabilities().values():
		total += chance
	assert_almost_eq(total, 1.0, 1e-9, "the probabilities sum to 1")


func test_a_hider_model_reads_less_into_a_cell_every_rule_allows() -> void:
	# An inner cell is allowed by all 5 of the opponent's rules, an edge cell by
	# 4: a hider favours inner cells anyway, so picking one says less about R04.
	var view: PublicView = _opponent_places(Vector2i(2, 2)).public_view(AI)
	var uniform: Belief = Belief.of(view, OpponentModel.new())
	var hider: Belief = Belief.of(view, HiderModel.new(1.0, 0.0))
	var hider_ratio: float = hider.probability("R04") / hider.probability("OT")
	assert_gt(hider_ratio, 1.0, "still some evidence for the narrower rule")
	assert_lt(hider_ratio, uniform.probability("R04") / uniform.probability("OT"))


func test_tempered_evidence_moves_the_belief_less() -> void:
	var view: PublicView = _opponent_places(Vector2i(2, 2)).public_view(AI)
	var full: Belief = Belief.of(view, HiderModel.new(1.0, 0.2, 1.0))
	var tempered: Belief = Belief.of(view, HiderModel.new(1.0, 0.2, 0.4))
	assert_lt(tempered.probability("R04"), full.probability("R04"))
	assert_gt(tempered.probability("R04"), tempered.probability("OT"))


func test_a_placement_on_the_edge_rules_r04_out_for_good() -> void:
	var current_match: Match = _opponent_places(Vector2i(0, 0))
	var belief: Belief = Belief.new(HiderModel.new())
	belief.update(current_match.public_view(AI))
	assert_eq(belief.probability("R04"), 0.0)
	assert_false(belief.alive().has(_book.rule("R04")))
	# More inner placements, which R04 would favour, never bring it back.
	assert_true(current_match.submit(OPPONENT, Command.pick_colour(BallColour.BLUE)))
	assert_true(current_match.submit(AI, Command.place(Vector2i(5, 5))))
	assert_true(current_match.submit(AI, Command.pick_colour(BallColour.BLUE)))
	assert_true(current_match.submit(OPPONENT, Command.place(Vector2i(3, 3))))
	belief.update(current_match.public_view(AI))
	assert_eq(belief.probability("R04"), 0.0)


func test_the_top_rule_is_the_most_likely_one() -> void:
	var belief: Belief = Belief.of(_opponent_places(Vector2i(2, 2)).public_view(AI), OpponentModel.new())
	assert_eq(belief.top(Fixtures.rng(1)).id, "R04")


func test_kept_through_a_match_it_matches_one_built_afresh() -> void:
	for seed_value: int in 5:
		var rng: RandomNumberGenerator = Fixtures.rng(seed_value)
		var decks: Array[Deck] = [Deck.draw(_book, rng), Deck.draw(_book, rng)]
		var secret_rules: Array[Rule] = [decks[0].random_rule(rng), decks[1].random_rule(rng)]
		var current_match: Match = Match.create(decks, secret_rules, rng)
		var ais: Array[AIController] = [AIController.new(Fixtures.rng(1), GuessPolicy.new(INF)), AIController.new(Fixtures.rng(2), GuessPolicy.new(INF))]
		var kept: Belief = Belief.new(HiderModel.new())
		var steps: int = 0
		while current_match.phase() != Match.Phase.OVER and steps < 40:
			steps += 1
			var player: int = current_match.awaiting_players()[0]
			if player == AI:
				var view: PublicView = current_match.public_view(AI)
				kept.update(view)
				var fresh: Belief = Belief.of(view, HiderModel.new())
				for rule_id: String in fresh.probabilities():
					assert_almost_eq(kept.probability(rule_id), fresh.probability(rule_id), 1e-9, "seed %d, %s" % [seed_value, rule_id])
			assert_true(current_match.submit(player, await ais[player].decide(current_match.public_view(player))))


func test_a_new_match_starts_it_afresh() -> void:
	var belief: Belief = Belief.new(OpponentModel.new())
	belief.update(_opponent_places(Vector2i(0, 0)).public_view(AI))
	var next: PublicView = _opponent_places(Vector2i(2, 2)).public_view(AI)
	belief.update(next)
	var fresh: Belief = Belief.of(next, OpponentModel.new())
	assert_almost_eq(belief.probability("R04"), fresh.probability("R04"), 1e-9, "R04 is back: a new history")


func test_about_the_viewer_it_reads_the_viewers_own_moves() -> void:
	var current_match: Match = _opponent_places(Vector2i(2, 2))
	assert_true(current_match.submit(OPPONENT, Command.pick_colour(BallColour.BLUE)))
	assert_true(current_match.submit(AI, Command.place(Vector2i(5, 5))))
	var exposure: Belief = Belief.of(current_match.public_view(AI), HiderModel.new(), true)
	assert_eq(exposure.probability("R04"), 0.0, "the AI's own edge placement rules its R04 out")
	assert_almost_eq(exposure.probability("AT"), 1.0 / (Deck.SIZE - 1), 1e-9)


func test_a_view_that_rules_every_rule_out_leaves_no_top_rule() -> void:
	var view: PublicView = _opponent_places(Vector2i(0, 0)).public_view(AI)
	view.decks[OPPONENT] = Deck.new([_book.rule("R04")] as Array[Rule])
	var belief: Belief = Belief.of(view, OpponentModel.new())
	assert_eq(belief.alive(), [] as Array[Rule])
	assert_null(belief.top(Fixtures.rng(1)))
