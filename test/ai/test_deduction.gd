extends GutTest

# The AI seam for deduction: given a PublicView, check which opponent rules the
# AI still holds as candidates. Views come from real matches.

const Fixtures := preload("res://test/helpers/fixtures.gd")

## The AI's player in these matches; the opponent is player 0.
const AI: int = 1
const OPPONENT: int = 0

var _book: RuleBook


func before_each() -> void:
	_book = Fixtures.book()


## A match on an empty board waiting for the first colour pick. The opponent
## holds a permissive true rule "OT" plus the given rules; the AI's deck is
## permissive.
func _match(opponent_rules: Array[String], first_player: int) -> Match:
	var opponent_deck: Array[Rule] = [Fixtures.anywhere(_book, "OT")]
	for rule_id: String in opponent_rules:
		opponent_deck.append(_book.rule(rule_id))
	var ai_true_rule: Rule = Fixtures.anywhere(_book, "AT")
	var decks: Array[Deck] = [Deck.new(opponent_deck), Fixtures.deck_with(_book, ai_true_rule, "A")]
	var true_rules: Array[Rule] = [opponent_deck[0], ai_true_rule]
	var position: MatchPosition = MatchPosition.new(Board.new(), first_player)
	return Match.from_position(position, decks, true_rules, Fixtures.rng(1))


## Submits each command for the player the match awaits.
func _play(current_match: Match, commands: Array[Command]) -> void:
	for command: Command in commands:
		var player: int = current_match.awaiting_players()[0]
		assert_true(current_match.submit(player, command), "player %d: %s" % [player, command])


## Placements alternating with red colour picks, starting with the first colour.
func _placements(cells: Array[Vector2i]) -> Array[Command]:
	var commands: Array[Command] = [Command.pick_colour(BallColour.RED)]
	for cell: Vector2i in cells:
		commands.append(Command.place(cell))
		commands.append(Command.pick_colour(BallColour.RED))
	return commands


func _candidate_ids(current_match: Match) -> Array[String]:
	var ids: Array[String] = []
	for rule: Rule in Deduction.candidates(current_match.public_view(AI)):
		ids.append(rule.id)
	return ids


func test_before_the_opponent_acts_every_rule_of_their_deck_is_a_candidate() -> void:
	var current_match: Match = _match(["R04", "R07", "R08", "R03"], OPPONENT)
	assert_eq(_candidate_ids(current_match), ["OT", "R04", "R07", "R08", "R03"] as Array[String])
	_play(current_match, [Command.pick_colour(BallColour.RED)])
	assert_eq(_candidate_ids(current_match), ["OT", "R04", "R07", "R08", "R03"] as Array[String])


func test_a_placement_rules_out_the_rules_it_breaks() -> void:
	var current_match: Match = _match(["R04", "R07", "R08", "R03"], OPPONENT)
	# (0, 0) is on the edge, and on row 6 counted from player 0's side.
	_play(current_match, _placements([Vector2i(0, 0)]))
	assert_eq(_candidate_ids(current_match), ["OT", "R07", "R08", "R03"] as Array[String])


func test_a_placement_is_judged_on_the_board_as_it_was_then() -> void:
	var current_match: Match = _match(["R04", "R07", "R08", "R03"], OPPONENT)
	# The AI then places next to the opponent's ball: R07 allowed that
	# placement when it was made.
	_play(current_match, _placements([Vector2i(2, 2), Vector2i(2, 3)]))
	assert_has(_candidate_ids(current_match), "R07")
	_play(current_match, [Command.place(Vector2i(1, 4))])
	assert_does_not_have(_candidate_ids(current_match), "R07", "placed next to the AI's ball")


func test_the_last_ball_is_the_one_placed_before_that_placement() -> void:
	var current_match: Match = _match(["R04", "R07", "R08", "R03"], OPPONENT)
	# Opponent: (1, 1), (4, 4), (2, 2). (2, 2) touches (1, 1) but not the ball
	# placed just before it; the AI places far away.
	_play(current_match, _placements([Vector2i(1, 1), Vector2i(5, 0), Vector2i(4, 4), Vector2i(5, 1), Vector2i(2, 2), Vector2i(5, 2)]))
	assert_has(_candidate_ids(current_match), "R08")
	_play(current_match, [Command.place(Vector2i(3, 3))])
	assert_does_not_have(_candidate_ids(current_match), "R08", "(3, 3) touches (2, 2)")


func test_rows_are_counted_from_the_first_players_side() -> void:
	# The AI goes first, so rows count from the top: y 1 is row 2, y 4 row 5.
	var current_match: Match = _match(["R04", "R07", "R08", "R03"], AI)
	_play(current_match, _placements([Vector2i(5, 5), Vector2i(2, 1)]))
	assert_has(_candidate_ids(current_match), "R03")
	current_match = _match(["R04", "R07", "R08", "R03"], AI)
	_play(current_match, _placements([Vector2i(5, 5), Vector2i(2, 4)]))
	assert_does_not_have(_candidate_ids(current_match), "R03")


## The AI (player 1) is to place yellow in the last inner cell, (3, 3). The
## opponent's true rule is R04, so once the inner cells are full they skip.
## Every edge cell touches a red ball.
func _skip_match() -> Match:
	var position: MatchPosition = MatchPosition.new(Board.parse([
		"......",
		".RrRr.",
		".rYyR.",
		".Rg.r.",
		".rRrR.",
		"......",
	]), OPPONENT)
	position.turn = 16
	position.colour = BallColour.YELLOW
	var r04: Rule = _book.rule("R04")
	var opponent_deck: Array[Rule] = [r04, _book.rule("R01"), _book.rule("R03"), _book.rule("R18"), Fixtures.anywhere(_book, "O1")]
	var ai_true_rule: Rule = Fixtures.anywhere(_book, "AT")
	var decks: Array[Deck] = [Deck.new(opponent_deck), Fixtures.deck_with(_book, ai_true_rule, "A")]
	var true_rules: Array[Rule] = [r04, ai_true_rule]
	return Match.from_position(position, decks, true_rules, Fixtures.rng(1))


func test_a_skip_rules_out_the_rules_that_would_have_allowed_a_cell_for_that_colour() -> void:
	var current_match: Match = _skip_match()
	_play(current_match, [Command.place(Vector2i(3, 3)), Command.pick_colour(BallColour.RED)])
	assert_eq(str(current_match.history().back()), "player 0 skips red")
	# R01 had no cell for red: every empty cell touches a red ball.
	assert_eq(_candidate_ids(current_match), ["R04", "R01"] as Array[String])


func test_a_skip_stays_judged_for_the_skipped_colour() -> void:
	var current_match: Match = _skip_match()
	_play(current_match, [Command.place(Vector2i(3, 3)), Command.pick_colour(BallColour.RED), Command.pick_colour(BallColour.BLUE)])
	assert_eq(current_match.current_player(), AI)
	assert_eq(_candidate_ids(current_match), ["R04", "R01"] as Array[String], "R01 would allow blue, not red")


# Candidates only shrink as history grows, so checking each match's final
# view covers every view before it.
func test_over_many_seeded_matches_the_true_rule_is_never_ruled_out() -> void:
	var ruled_out: int = 0
	for seed_value: int in 60:
		var rng: RandomNumberGenerator = Fixtures.rng(seed_value)
		var decks: Array[Deck] = [Deck.draw(_book, rng), Deck.draw(_book, rng)]
		var true_rules: Array[Rule] = []
		for deck: Deck in decks:
			true_rules.append(deck.random_rule(rng))
		var current_match: Match = Match.create(decks, true_rules, rng)
		var controllers: Array[Controller] = [AIController.new(Fixtures.rng(seed_value + 100)), AIController.new(Fixtures.rng(seed_value + 200))]
		while current_match.phase() != Match.Phase.OVER:
			var player: int = current_match.awaiting_players()[0]
			assert_true(current_match.submit(player, await controllers[player].decide(current_match.public_view(player))))
		for viewer: int in Players.COUNT:
			var opponent_true_rule: Rule = true_rules[Players.opponent(viewer)]
			var candidates: Array[Rule] = Deduction.candidates(current_match.public_view(viewer))
			assert_has(candidates, opponent_true_rule, "seed %d, player %d" % [seed_value, viewer])
			ruled_out += Deck.SIZE - candidates.size()
	assert_gt(ruled_out, 100, "the matches rule some rules out")
