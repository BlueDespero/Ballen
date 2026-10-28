extends GutTest

# The history view's state, stepped through on player 0's view of a match
# played by commands: which past turn is on show, and what is said about it.

const Fixtures := preload("res://test/helpers/fixtures.gd")

var _book: RuleBook
var _match: Match
var _browser: HistoryBrowser


func before_each() -> void:
	_book = Fixtures.book()
	_browser = HistoryBrowser.new()


## Player 0 goes first; permissive true rules "AT" and "BT", or the given one
## for player 1.
func _start(true_rule_1: Rule = null) -> void:
	if true_rule_1 == null:
		true_rule_1 = Fixtures.anywhere(_book, "BT")
	var true_rules: Array[Rule] = [Fixtures.anywhere(_book, "AT"), true_rule_1]
	var decks: Array[Deck] = [Fixtures.deck_with(_book, true_rules[0], "A"), Fixtures.deck_with(_book, true_rules[1], "B")]
	_match = Match.create(decks, true_rules, Fixtures.rng(1), 0)


## Submits each command for the player the match awaits, then shows the
## browser player 0's view.
func _play(commands: Array[Command]) -> void:
	for command: Command in commands:
		var player: int = _match.awaiting_players()[0]
		assert_true(_match.submit(player, command), "player %d: %s" % [player, command])
	_browser.live_view = _match.public_view(0)


## Three turns: player 0 places red, player 1 blue, player 0 green; turn 4
## has begun.
func _three_turns() -> void:
	_start()
	_play([
		Command.pick_colour(BallColour.RED), Command.place(Vector2i(0, 5)),
		Command.pick_colour(BallColour.BLUE), Command.place(Vector2i(1, 0)),
		Command.pick_colour(BallColour.GREEN), Command.place(Vector2i(2, 5)),
		Command.pick_colour(BallColour.YELLOW),
	])


func test_the_live_board_is_on_show_at_first() -> void:
	_three_turns()
	assert_false(_browser.viewing_past())
	assert_eq(_browser.viewed_turn, HistoryBrowser.LIVE)


func test_back_from_live_shows_the_latest_turn_with_a_placement() -> void:
	_three_turns()
	assert_true(_browser.step_back())
	assert_eq(_browser.viewed_turn, 3)
	assert_eq(str(_browser.past_position().history[-1]), "player 0 places green at (2, 5)")


func test_back_stops_at_the_first_turn() -> void:
	_three_turns()
	for i: int in 3:
		_browser.step_back()
	assert_eq(_browser.viewed_turn, 1)
	assert_false(_browser.can_go_back())
	assert_false(_browser.step_back())
	assert_eq(_browser.viewed_turn, 1)


func test_forward_past_the_latest_turn_returns_to_live() -> void:
	_three_turns()
	_browser.step_back()
	_browser.step_back()
	assert_true(_browser.step_forward())
	assert_eq(_browser.viewed_turn, 3)
	assert_true(_browser.step_forward())
	assert_false(_browser.viewing_past())
	assert_false(_browser.step_forward(), "already live")


func test_live_returns_from_a_past_turn() -> void:
	_three_turns()
	_browser.step_back()
	assert_true(_browser.go_live())
	assert_false(_browser.viewing_past())
	assert_false(_browser.go_live(), "already live")


func test_nothing_to_browse_before_the_first_placement() -> void:
	_start()
	_play([Command.pick_colour(BallColour.RED)])
	assert_false(_browser.can_go_back())
	assert_false(_browser.step_back())


func test_nothing_to_browse_without_a_match_or_while_busy() -> void:
	assert_false(_browser.can_browse(), "no match yet")
	_three_turns()
	_browser.busy = true
	assert_false(_browser.step_back())
	_browser.busy = false
	assert_true(_browser.step_back())
	_browser.reset()
	assert_false(_browser.viewing_past())
	assert_false(_browser.can_browse(), "a new match is about to start")


func test_the_match_moving_on_keeps_the_past_turn_on_show() -> void:
	_three_turns()
	_browser.step_back()
	_browser.step_back()
	_play([Command.place(Vector2i(3, 0))])
	assert_eq(_browser.viewed_turn, 2)
	assert_true(_browser.moved_on)
	assert_eq(_browser.latest_turn(), 4)


func test_returning_to_live_clears_the_moved_on_note() -> void:
	_three_turns()
	_browser.step_back()
	_play([Command.place(Vector2i(3, 0))])
	_browser.go_live()
	assert_false(_browser.moved_on)


func test_a_redraw_without_new_events_is_not_moving_on() -> void:
	_three_turns()
	_browser.step_back()
	_browser.live_view = _match.public_view(0)
	assert_false(_browser.moved_on)


func test_a_finished_match_returns_to_live_and_closes_browsing() -> void:
	_three_turns()
	_browser.step_back()
	_play([Command.guess("AT")])
	assert_false(_browser.viewing_past())
	assert_false(_browser.can_browse())


func test_a_past_placement_says_who_placed_which_colour() -> void:
	_three_turns()
	_browser.step_back()
	_browser.step_back()
	assert_string_starts_with(_browser.past_turn_text(), "Turn 2 of 3: the AI placed blue.")
	_browser.step_back()
	assert_string_starts_with(_browser.past_turn_text(), "Turn 1 of 3: you placed red.")


func test_a_past_skip_says_whose_ball_was_skipped() -> void:
	_book.add_template("nowhere", {"blanks": {}, "tree": {"part": "count_at_most", "n": 0, "of": {"part": "target"}}})
	_start(_book.make_rule({"id": "BN", "text": "Nowhere", "template": "nowhere", "values": {}}))
	_play([
		Command.pick_colour(BallColour.RED), Command.place(Vector2i(0, 5)),
		Command.pick_colour(BallColour.BLUE), # player 1 has no legal cell and skips
	])
	_browser.step_back()
	assert_string_starts_with(_browser.past_turn_text(),
		"Turn 2 of 2: the AI had no legal cell for blue, so the ball was skipped.")
