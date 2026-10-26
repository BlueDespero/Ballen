extends GutTest

# What the match-end screen tells each viewer, built from their PublicView once
# the match is over: win, lose or draw, how the match ended and both true rules.

const Fixtures := preload("res://test/helpers/fixtures.gd")

var _book: RuleBook


func before_each() -> void:
	_book = Fixtures.book()


## A match whose true rules are "AT" (player 0) and "BT" (player 1), past the
## first colour pick: the first player is to place.
func _started(seed_value: int) -> Match:
	var game: Match = Fixtures.new_match(_book, Fixtures.anywhere(_book, "AT"), Fixtures.anywhere(_book, "BT"), seed_value)
	game.submit(Players.opponent(game.first_player()), Command.pick_colour(BallColour.RED))
	return game


## A match that ended when the guesser named this rule at the start of their
## first turn. The first seed whose coin toss lets the guesser go first.
func _guessed(guesser: int, rule_id: String) -> Match:
	var game: Match = _started(1)
	var seed_value: int = 1
	while game.current_player() != guesser:
		seed_value += 1
		game = _started(seed_value)
	assert_true(game.submit(guesser, Command.guess(rule_id)))
	return game


func test_a_right_guess_wins_for_the_guesser() -> void:
	var summary: MatchEndSummary = MatchEndSummary.from_view(_guessed(0, "BT").public_view(0))
	assert_eq(summary.outcome, MatchEndSummary.Outcome.WIN)
	assert_eq(summary.headline, "You win")
	assert_eq(summary.reason, "You named BT \"Anywhere (BT)\", the AI's true rule.")


func test_the_other_viewer_loses_the_same_match() -> void:
	var summary: MatchEndSummary = MatchEndSummary.from_view(_guessed(0, "BT").public_view(1))
	assert_eq(summary.outcome, MatchEndSummary.Outcome.LOSS)
	assert_eq(summary.headline, "You lose")
	assert_eq(summary.reason, "The AI named BT \"Anywhere (BT)\", your true rule.")


func test_a_wrong_guess_loses_for_the_guesser() -> void:
	var summary: MatchEndSummary = MatchEndSummary.from_view(_guessed(0, "B2").public_view(0))
	assert_eq(summary.outcome, MatchEndSummary.Outcome.LOSS)
	assert_eq(summary.headline, "You lose")
	assert_eq(summary.reason, "You named B2 \"Anywhere (B2)\", but it isn't the AI's true rule.")


func test_the_ais_wrong_guess_wins_for_the_viewer() -> void:
	var summary: MatchEndSummary = MatchEndSummary.from_view(_guessed(1, "A2").public_view(0))
	assert_eq(summary.outcome, MatchEndSummary.Outcome.WIN)
	assert_eq(summary.headline, "You win")
	assert_eq(summary.reason, "The AI named A2 \"Anywhere (A2)\", but it isn't your true rule.")


func test_each_viewer_sees_both_true_rules_from_their_side() -> void:
	var game: Match = _guessed(0, "B2")
	var mine: MatchEndSummary = MatchEndSummary.from_view(game.public_view(0))
	assert_eq(mine.own_true_rule.id, "AT")
	assert_eq(mine.opponent_true_rule.id, "BT")
	var theirs: MatchEndSummary = MatchEndSummary.from_view(game.public_view(1))
	assert_eq(theirs.own_true_rule.id, "BT")
	assert_eq(theirs.opponent_true_rule.id, "AT")


func test_there_is_no_summary_while_the_match_runs() -> void:
	assert_null(MatchEndSummary.from_view(_started(1).public_view(0)))


## A match that ended as it started: player 0 holds R04, the 16 inner cells
## are full and it is their turn with 2 skips, so their third skip loses.
func _third_skip_by_player_0() -> Match:
	var position: MatchPosition = MatchPosition.from_board(Board.parse([
		"......",
		".RbRb.",
		".bRbR.",
		".RbRb.",
		".bRbR.",
		"......",
	]), 0)
	position.turn = 17
	position.colour = BallColour.RED
	position.skips = [2, 0]
	var r04: Rule = _book.rule("R04")
	var bt: Rule = Fixtures.anywhere(_book, "BT")
	var decks: Array[Deck] = [Fixtures.deck_with(_book, r04, "A"), Fixtures.deck_with(_book, bt, "B")]
	var true_rules: Array[Rule] = [r04, bt]
	var game: Match = Match.from_position(position, decks, true_rules, Fixtures.rng(1))
	assert_eq(game.phase(), Match.Phase.OVER)
	return game


func test_the_viewers_third_skip_loses() -> void:
	var summary: MatchEndSummary = MatchEndSummary.from_view(_third_skip_by_player_0().public_view(0))
	assert_eq(summary.outcome, MatchEndSummary.Outcome.LOSS)
	assert_eq(summary.headline, "You lose")
	assert_eq(summary.reason, "You skipped for the third time.")


func test_the_ais_third_skip_wins_for_the_viewer() -> void:
	var summary: MatchEndSummary = MatchEndSummary.from_view(_third_skip_by_player_0().public_view(1))
	assert_eq(summary.outcome, MatchEndSummary.Outcome.WIN)
	assert_eq(summary.reason, "The AI skipped for the third time.")


## The view of a match that ended with this result after the closing history
## entries. Forced guesses (#50) can't be played to the end yet, so their views
## are built from a running match's view; switch to real matches once they can.
func _ended_view(viewer: int, result: MatchResult, closing: Array[HistoryEntry]) -> PublicView:
	var view: PublicView = _started(1).public_view(viewer)
	view.phase = Match.Phase.OVER
	view.result = result
	var true_rules: Array[Rule] = [view.decks[0].rules[0], view.decks[1].rules[0]]
	view.revealed_true_rules = true_rules
	view.position.history.append_array(closing)
	return view


func test_two_wrong_forced_guesses_draw_and_list_the_viewers_guess_first() -> void:
	var result: MatchResult = MatchResult.new(Players.NONE, MatchResult.Reason.FORCED_GUESSES)
	var closing: Array[HistoryEntry] = [HistoryEntry.guess(1, "A3", false), HistoryEntry.guess(0, "B2", false)]
	var summary: MatchEndSummary = MatchEndSummary.from_view(_ended_view(0, result, closing))
	assert_eq(summary.outcome, MatchEndSummary.Outcome.DRAW)
	assert_eq(summary.headline, "Draw")
	assert_eq(summary.reason, "The board is full. "
		+ "You named B2 \"Anywhere (B2)\", but it isn't the AI's true rule. "
		+ "The AI named A3 \"Anywhere (A3)\", but it isn't your true rule.")


func test_the_only_right_forced_guess_wins() -> void:
	var result: MatchResult = MatchResult.new(1, MatchResult.Reason.FORCED_GUESSES)
	var closing: Array[HistoryEntry] = [HistoryEntry.guess(0, "B2", false), HistoryEntry.guess(1, "AT", true)]
	var summary: MatchEndSummary = MatchEndSummary.from_view(_ended_view(1, result, closing))
	assert_eq(summary.outcome, MatchEndSummary.Outcome.WIN)
	assert_eq(summary.reason, "The board is full. "
		+ "You named AT \"Anywhere (AT)\", the AI's true rule. "
		+ "The AI named B2 \"Anywhere (B2)\", but it isn't your true rule.")
