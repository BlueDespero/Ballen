extends GutTest

# One-time hints for a new player: each shows only while the player could do
# what it says, and never again once they have.

const Fixtures := preload("res://test/helpers/fixtures.gd")
const PATH: String = "user://test_coach_mark_settings.cfg"
const PLAYER: int = 0
const AI: int = 1

var _book: RuleBook
var _settings: GameSettings


func before_each() -> void:
	_book = Fixtures.book()
	DirAccess.remove_absolute(PATH)
	_settings = autofree(GameSettings.new())
	_settings.path = PATH
	_settings.load_settings()


func after_all() -> void:
	DirAccess.remove_absolute(PATH)


func _match(player_first: bool) -> Match:
	var secret_rules: Array[Rule] = [Fixtures.anywhere(_book, "AT"), Fixtures.anywhere(_book, "BT")]
	var decks: Array[Deck] = [Fixtures.deck_with(_book, secret_rules[0], "A"), Fixtures.deck_with(_book, secret_rules[1], "B")]
	return Match.create(decks, secret_rules, Fixtures.rng(1), PLAYER if player_first else AI)


func _hint(game: Match) -> String:
	return CoachMark.hint_for(game.public_view(PLAYER), _settings)


## The player goes second: they pick, the AI places, then it's their turn.
func _after_the_ai_placed() -> Match:
	var game: Match = _match(false)
	game.submit(PLAYER, Command.pick_colour(BallColour.RED))
	game.submit(AI, Command.place(Vector2i(0, 0)))
	game.submit(AI, Command.pick_colour(BallColour.BLUE))
	return game


func test_the_colour_pick_hint_shows_while_a_pick_is_due() -> void:
	assert_eq(_hint(_match(false)), GameSettings.HINT_COLOUR_PICK)


func test_the_colour_pick_hint_is_gone_once_the_player_has_picked() -> void:
	_settings.mark_hint_seen(GameSettings.HINT_COLOUR_PICK)
	assert_eq(_hint(_match(false)), "")


func test_the_watch_hint_shows_when_placing_after_the_ai_placed() -> void:
	assert_eq(_hint(_after_the_ai_placed()), GameSettings.HINT_WATCH_AI)


func test_no_watch_hint_before_the_ai_has_placed() -> void:
	var game: Match = _match(true)
	game.submit(AI, Command.pick_colour(BallColour.RED))
	assert_eq(_hint(game), "", "placing first, with nothing to read yet")


func test_the_watch_hint_is_gone_once_the_player_uses_a_note_mark() -> void:
	_settings.note_marks_seen = true
	assert_eq(_hint(_after_the_ai_placed()), "")


func test_the_watch_hint_is_gone_after_the_first_match() -> void:
	_settings.mark_hint_seen(GameSettings.HINT_WATCH_AI)
	assert_eq(_hint(_after_the_ai_placed()), "")


func test_every_hint_has_text() -> void:
	for hint: String in GameSettings.ONE_TIME_HINTS:
		assert_ne(CoachMark.text_for(hint), "", hint)
