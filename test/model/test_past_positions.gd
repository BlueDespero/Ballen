extends GutTest

# The match seam for past positions: play commands, then rebuild the position
# after a past turn from the player's PublicView (the history view, #26).

const Fixtures := preload("res://test/helpers/fixtures.gd")

var _book: RuleBook


func before_each() -> void:
	_book = Fixtures.book()


## A match with a permissive true rule for player 0 (and for player 1 unless
## given); player 0 goes first.
func _match(true_rule_1: Rule = null) -> Match:
	if true_rule_1 == null:
		true_rule_1 = Fixtures.anywhere(_book, "BT")
	var true_rules: Array[Rule] = [Fixtures.anywhere(_book, "AT"), true_rule_1]
	var decks: Array[Deck] = [Fixtures.deck_with(_book, true_rules[0], "A"), Fixtures.deck_with(_book, true_rules[1], "B")]
	return Match.create(decks, true_rules, Fixtures.rng(1), 0)


## Submits each command for the player the match awaits.
func _play(current_match: Match, commands: Array[Command]) -> void:
	for command: Command in commands:
		var player: int = current_match.awaiting_players()[0]
		assert_true(current_match.submit(player, command), "player %d: %s" % [player, command])


## The board as 6 strings, top row first, in Board.parse's notation.
func _rows(board: Board) -> Array[String]:
	var letters: Dictionary[String, String] = {
		BallColour.YELLOW: "y", BallColour.BLUE: "b", BallColour.RED: "r", BallColour.GREEN: "g"}
	var rows: Array[String] = []
	for y: int in Board.SIZE:
		var row: String = ""
		for x: int in Board.SIZE:
			var ball: Ball = board.ball_at(Vector2i(x, y))
			if ball == null:
				row += "."
			else:
				var letter: String = letters[ball.colour]
				row += letter.to_upper() if ball.owner == 0 else letter
		rows.append(row)
	return rows


## Three turns: player 0 places red, player 1 blue, player 0 green.
func _three_turns() -> Match:
	var current_match: Match = _match()
	_play(current_match, [
		Command.pick_colour(BallColour.RED), Command.place(Vector2i(0, 5)),
		Command.pick_colour(BallColour.BLUE), Command.place(Vector2i(1, 0)),
		Command.pick_colour(BallColour.GREEN), Command.place(Vector2i(2, 5)),
		Command.pick_colour(BallColour.YELLOW),
	])
	return current_match


func test_the_board_after_a_past_turn_holds_only_the_balls_placed_by_then() -> void:
	var position: MatchPosition = _three_turns().public_view(0).position
	assert_eq(_rows(position.after_turn(1).board), [
		"......", "......", "......", "......", "......", "R....."] as Array[String])
	assert_eq(_rows(position.after_turn(2).board), [
		".b....", "......", "......", "......", "......", "R....."] as Array[String])


func test_the_turns_placement_is_the_last_event_of_the_past_position() -> void:
	var after: MatchPosition = _three_turns().public_view(0).position.after_turn(2)
	assert_eq(str(after.history[-1]), "player 1 places blue at (1, 0)")
	assert_eq(after.turn, 2)
	assert_eq(after.colour, BallColour.BLUE)


func test_a_skipped_turn_ends_with_the_skip_and_counts_it() -> void:
	_book.add_template("nowhere", {"blanks": {}, "tree": {"part": "count_at_most", "n": 0, "of": {"part": "target"}}})
	var nowhere: Rule = _book.make_rule({"id": "BN", "text": "Nowhere", "template": "nowhere", "values": {}})
	var current_match: Match = _match(nowhere)
	_play(current_match, [
		Command.pick_colour(BallColour.RED), Command.place(Vector2i(0, 5)),
		Command.pick_colour(BallColour.BLUE), # player 1 has no legal cell and skips
		Command.pick_colour(BallColour.GREEN), Command.place(Vector2i(2, 5)),
	])
	var after: MatchPosition = current_match.public_view(0).position.after_turn(2)
	assert_eq(str(after.history[-1]), "player 1 skips blue")
	assert_eq(after.skips, [0, 1] as Array[int])
	assert_eq(_rows(after.board), [
		"......", "......", "......", "......", "......", "R....."] as Array[String])


func test_turns_without_a_placement_or_skip_yet_have_no_past_position() -> void:
	var position: MatchPosition = _three_turns().public_view(0).position
	assert_null(position.after_turn(0), "turn 0 is only the first colour pick")
	assert_null(position.after_turn(4), "turn 4 has begun, but nothing is placed yet")
	assert_null(position.after_turn(5), "turn 5 hasn't begun")


func test_every_past_turn_rebuilds_the_position_the_match_had_then() -> void:
	for seed_value: int in 5:
		# R04 for both and never-guessing AIs: placements, then skips until a third one.
		var r04: Rule = _book.rule("R04")
		var current_match: Match = Fixtures.new_match(_book, r04, r04, seed_value)
		var rng: RandomNumberGenerator = Fixtures.rng(seed_value)
		var ais: Array[AIController] = [AIController.new(rng, GuessPolicy.new(INF)), AIController.new(rng, GuessPolicy.new(INF))]
		var seen: Dictionary[int, MatchPosition] = {} # turn -> the live position right after its placement or skip
		while current_match.phase() != Match.Phase.OVER:
			var player: int = current_match.awaiting_players()[0]
			assert_true(current_match.submit(player, ais[player].decide(current_match.public_view(player))))
			var live: MatchPosition = current_match.public_view(0).position
			var last: HistoryEntry = live.history[-1]
			if last.is_placement_or_skip():
				seen[live.turn] = live
		var position: MatchPosition = current_match.public_view(0).position
		assert_gt(position.skips[0] + position.skips[1], 2, "seed %d reached skips" % seed_value)
		for turn: int in seen:
			var then: MatchPosition = seen[turn]
			var rebuilt: MatchPosition = position.after_turn(turn)
			var context: String = "seed %d, turn %d" % [seed_value, turn]
			assert_eq(_rows(rebuilt.board), _rows(then.board), context)
			assert_eq(rebuilt.turn, then.turn, context)
			assert_eq(rebuilt.colour, then.colour, context)
			assert_eq(rebuilt.skips, then.skips, context)
			assert_eq(rebuilt.history.size(), then.history.size(), context)
			assert_eq(str(rebuilt.history[-1]), str(then.history[-1]), context)
		assert_null(position.after_turn(position.turn + 1), "seed %d" % seed_value)
