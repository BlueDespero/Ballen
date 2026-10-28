extends GutTest

# The match seam for a full board: after the placement that fills it (and the
# placer's optional guess) both players make a sealed forced guess. Exactly one
# right wins; both right or both wrong is a draw.

const Fixtures := preload("res://test/helpers/fixtures.gd")
const ObjectWalker := preload("res://test/helpers/object_walker.gd")

var _book: RuleBook


func before_each() -> void:
	_book = Fixtures.book()


## Player 0 is to place the last ball. True rules "AT" (player 0) and "BT"
## (player 1), decks filled with A1..A4 / B1..B4; every rule allows every
## empty cell.
func _nearly_full() -> Match:
	return Fixtures.nearly_full_match(_book)


## The nearly full match after player 0 fills the board.
func _full() -> Match:
	var current_match: Match = _nearly_full()
	assert_true(current_match.submit(0, Command.place(Fixtures.LAST_EMPTY_CELL)))
	return current_match


func test_filling_the_board_starts_the_forced_guesses_with_the_placer() -> void:
	var current_match: Match = _full()
	assert_eq(current_match.phase(), Match.Phase.FORCED_GUESS)
	assert_eq(current_match.awaiting_players(), [0] as Array[int])


func test_a_full_board_has_no_colour_pick() -> void:
	var current_match: Match = _full()
	assert_false(current_match.submit(0, Command.pick_colour(BallColour.BLUE)))
	assert_eq(current_match.phase(), Match.Phase.FORCED_GUESS)


func test_after_the_placers_forced_guess_the_match_awaits_the_opponents() -> void:
	var current_match: Match = _full()
	assert_true(current_match.submit(0, Command.forced_guess("B2")))
	assert_eq(current_match.phase(), Match.Phase.FORCED_GUESS)
	assert_eq(current_match.awaiting_players(), [1] as Array[int])
	assert_false(current_match.submit(0, Command.forced_guess("BT")), "one forced guess each")


## The full match after player 0 names placer_rule_id and player 1 names
## opponent_rule_id as forced guesses.
func _forced(placer_rule_id: String, opponent_rule_id: String) -> Match:
	var current_match: Match = _full()
	assert_true(current_match.submit(0, Command.forced_guess(placer_rule_id)))
	assert_true(current_match.submit(1, Command.forced_guess(opponent_rule_id)))
	return current_match


func test_only_the_placers_right_forced_guess_wins_for_the_placer() -> void:
	var current_match: Match = _forced("BT", "A2")
	assert_eq(current_match.phase(), Match.Phase.OVER)
	assert_eq(current_match.awaiting_players(), [] as Array[int])
	assert_eq(current_match.result().winner, 0)
	assert_eq(current_match.result().reason, MatchResult.Reason.FORCED_GUESSES)


func test_only_the_opponents_right_forced_guess_wins_for_the_opponent() -> void:
	var current_match: Match = _forced("B2", "AT")
	assert_eq(current_match.result().winner, 1)
	assert_eq(current_match.result().reason, MatchResult.Reason.FORCED_GUESSES)


func test_two_right_forced_guesses_draw() -> void:
	var current_match: Match = _forced("BT", "AT")
	assert_eq(current_match.phase(), Match.Phase.OVER)
	assert_true(current_match.result().is_draw())
	assert_eq(current_match.result().reason, MatchResult.Reason.FORCED_GUESSES)


func test_two_wrong_forced_guesses_draw() -> void:
	var current_match: Match = _forced("B2", "A3")
	assert_true(current_match.result().is_draw())
	assert_eq(current_match.result().reason, MatchResult.Reason.FORCED_GUESSES)


func test_history_records_both_forced_guesses_once_both_are_in_the_placers_first() -> void:
	var current_match: Match = _full()
	var before: int = current_match.history().size()
	current_match.submit(0, Command.forced_guess("BT"))
	assert_eq(current_match.history().size(), before, "a sealed guess is not in the history")
	current_match.submit(1, Command.forced_guess("A3"))
	var history: Array[HistoryEntry] = current_match.history()
	assert_eq(history.size(), before + 2)
	assert_eq(str(history[-2]), "player 0 guesses BT, right")
	assert_eq(str(history[-1]), "player 1 guesses A3, wrong")


func test_a_sealed_forced_guess_is_in_no_public_view() -> void:
	var right: Match = _full()
	var wrong: Match = _full()
	assert_true(right.submit(0, Command.forced_guess("BT")))
	assert_true(wrong.submit(0, Command.forced_guess("B2")))
	for viewer: int in Players.COUNT:
		assert_eq_deep(ObjectWalker.dump(right.public_view(viewer)), ObjectWalker.dump(wrong.public_view(viewer)))


func test_the_placer_may_still_guess_and_win_before_the_forced_guess() -> void:
	var current_match: Match = _full()
	assert_true(current_match.submit(0, Command.guess("BT")))
	assert_eq(current_match.phase(), Match.Phase.OVER)
	assert_eq(current_match.result().winner, 0)
	assert_eq(current_match.result().reason, MatchResult.Reason.RIGHT_GUESS)


func test_the_placer_may_still_guess_and_lose_before_the_forced_guess() -> void:
	var current_match: Match = _full()
	assert_true(current_match.submit(0, Command.guess("B2")))
	assert_eq(current_match.result().winner, 1)
	assert_eq(current_match.result().reason, MatchResult.Reason.WRONG_GUESS)


func test_after_the_placers_forced_guess_no_one_may_guess() -> void:
	var current_match: Match = _full()
	current_match.submit(0, Command.forced_guess("B2"))
	assert_false(current_match.submit(0, Command.guess("BT")), "the placer's window closed with their forced guess")
	assert_false(current_match.submit(1, Command.guess("AT")), "never on the opponent's turn")
	assert_eq(current_match.phase(), Match.Phase.FORCED_GUESS)


func test_the_opponent_makes_their_forced_guess_after_the_placer() -> void:
	var current_match: Match = _full()
	assert_false(current_match.submit(1, Command.forced_guess("AT")))
	assert_eq(current_match.awaiting_players(), [0] as Array[int])


func test_a_forced_guess_must_name_a_rule_of_the_opponents_deck() -> void:
	var current_match: Match = _full()
	assert_false(current_match.submit(0, Command.forced_guess("AT")), "the guesser's own rule")
	assert_false(current_match.submit(0, Command.forced_guess("R04")), "a rule in no deck")
	assert_eq(current_match.awaiting_players(), [0] as Array[int])


func test_there_is_no_forced_guess_before_the_board_is_full() -> void:
	var current_match: Match = _nearly_full()
	assert_false(current_match.submit(0, Command.forced_guess("BT")))
	assert_eq(current_match.phase(), Match.Phase.PLACE)


func test_the_view_shows_the_placer_their_forced_guess_is_due_and_they_may_still_guess() -> void:
	var current_match: Match = _full()
	var placer: PublicView = current_match.public_view(0)
	assert_eq(placer.awaiting_players, [0] as Array[int])
	assert_true(placer.forced_guess_due())
	assert_true(placer.can_guess())
	var opponent: PublicView = current_match.public_view(1)
	assert_false(opponent.forced_guess_due())
	assert_false(opponent.can_guess())


func test_the_view_shows_the_opponent_their_forced_guess_is_due_after_the_placers() -> void:
	var current_match: Match = _full()
	current_match.submit(0, Command.forced_guess("B2"))
	var opponent: PublicView = current_match.public_view(1)
	assert_eq(opponent.awaiting_players, [1] as Array[int])
	assert_true(opponent.forced_guess_due())
	assert_false(opponent.can_guess(), "only the placer may pull the trigger")
	var placer: PublicView = current_match.public_view(0)
	assert_false(placer.forced_guess_due())
	assert_false(placer.can_guess())
