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
	var position: MatchPosition = MatchPosition.from_board(Board.new(), first_player)
	return Match.from_position(position, decks, true_rules, Fixtures.rng(1))


## Submits each command for the player the match awaits.
func _play(game: Match, commands: Array[Command]) -> void:
	for command: Command in commands:
		var player: int = game.awaiting_players()[0]
		assert_true(game.submit(player, command), "player %d: %s" % [player, command])


## Placements alternating with red colour picks, starting with the first colour.
func _placements(cells: Array[Vector2i]) -> Array[Command]:
	var commands: Array[Command] = [Command.pick_colour(BallColour.RED)]
	for cell: Vector2i in cells:
		commands.append(Command.place(cell))
		commands.append(Command.pick_colour(BallColour.RED))
	return commands


func _candidate_ids(game: Match) -> Array[String]:
	var ids: Array[String] = []
	for rule: Rule in Deduction.candidates(game.public_view(AI)):
		ids.append(rule.id)
	return ids


func test_before_the_opponent_acts_every_rule_of_their_deck_is_a_candidate() -> void:
	var game: Match = _match(["R04", "R07", "R08", "R03"], OPPONENT)
	assert_eq(_candidate_ids(game), ["OT", "R04", "R07", "R08", "R03"] as Array[String])
	_play(game, [Command.pick_colour(BallColour.RED)])
	assert_eq(_candidate_ids(game), ["OT", "R04", "R07", "R08", "R03"] as Array[String])


func test_a_placement_rules_out_the_rules_it_breaks() -> void:
	var game: Match = _match(["R04", "R07", "R08", "R03"], OPPONENT)
	# (0, 0) is on the edge, and on row 6 counted from player 0's side.
	_play(game, _placements([Vector2i(0, 0)]))
	assert_eq(_candidate_ids(game), ["OT", "R07", "R08", "R03"] as Array[String])


func test_a_placement_is_judged_on_the_board_as_it_was_then() -> void:
	var game: Match = _match(["R04", "R07", "R08", "R03"], OPPONENT)
	# The AI then places next to the opponent's ball: R07 allowed that
	# placement when it was made.
	_play(game, _placements([Vector2i(2, 2), Vector2i(2, 3)]))
	assert_has(_candidate_ids(game), "R07")
	_play(game, [Command.place(Vector2i(1, 4))])
	assert_does_not_have(_candidate_ids(game), "R07", "placed next to the AI's ball")


func test_the_last_ball_is_the_one_placed_before_that_placement() -> void:
	var game: Match = _match(["R04", "R07", "R08", "R03"], OPPONENT)
	# Opponent: (1, 1), (4, 4), (2, 2). (2, 2) touches (1, 1) but not the ball
	# placed just before it; the AI places far away.
	_play(game, _placements([Vector2i(1, 1), Vector2i(5, 0), Vector2i(4, 4), Vector2i(5, 1), Vector2i(2, 2), Vector2i(5, 2)]))
	assert_has(_candidate_ids(game), "R08")
	_play(game, [Command.place(Vector2i(3, 3))])
	assert_does_not_have(_candidate_ids(game), "R08", "(3, 3) touches (2, 2)")


func test_rows_are_counted_from_the_first_players_side() -> void:
	# The AI goes first, so rows count from the top: y 1 is row 2, y 4 row 5.
	var game: Match = _match(["R04", "R07", "R08", "R03"], AI)
	_play(game, _placements([Vector2i(5, 5), Vector2i(2, 1)]))
	assert_has(_candidate_ids(game), "R03")
	game = _match(["R04", "R07", "R08", "R03"], AI)
	_play(game, _placements([Vector2i(5, 5), Vector2i(2, 4)]))
	assert_does_not_have(_candidate_ids(game), "R03")
