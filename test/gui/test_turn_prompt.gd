extends GutTest

# The status beside the board: a short prompt saying what to do now, and a
# detail line that names guessing as the other option whenever it is open.

const Fixtures := preload("res://test/helpers/fixtures.gd")
const PLAYER: int = 0
const AI: int = 1

var _book: RuleBook


func before_each() -> void:
	_book = Fixtures.book()


## A new match, permissive rules on both sides, the player going first or not.
func _match(player_first: bool) -> Match:
	var secret_rules: Array[Rule] = [Fixtures.anywhere(_book, "AT"), Fixtures.anywhere(_book, "BT")]
	var decks: Array[Deck] = [Fixtures.deck_with(_book, secret_rules[0], "A"), Fixtures.deck_with(_book, secret_rules[1], "B")]
	return Match.create(decks, secret_rules, Fixtures.rng(1), PLAYER if player_first else AI)


func _prompt(game: Match) -> TurnPrompt:
	return TurnPrompt.for_view(game.public_view(PLAYER))


func test_going_first_the_player_waits_for_their_first_colour() -> void:
	var prompt: TurnPrompt = _prompt(_match(true))
	assert_eq(prompt.prompt, "You go first.")
	assert_eq(prompt.detail, "The AI is picking your first colour…")


func test_going_second_the_player_picks_the_ai_s_first_colour() -> void:
	var prompt: TurnPrompt = _prompt(_match(false))
	assert_eq(prompt.prompt, "Pick the AI's first colour.")
	assert_eq(prompt.detail, "The AI goes first.")


func test_on_their_turn_the_player_places_or_guesses() -> void:
	var game: Match = _match(true)
	game.submit(AI, Command.pick_colour(BallColour.RED))
	var prompt: TurnPrompt = _prompt(game)
	assert_eq(prompt.prompt, "Place your ball.")
	assert_string_contains(prompt.detail, "guess it", "guessing is named as the other option")


func test_after_placing_the_player_picks_a_colour_or_guesses() -> void:
	var game: Match = _match(true)
	game.submit(AI, Command.pick_colour(BallColour.RED))
	game.submit(PLAYER, Command.place(Vector2i(0, 5)))
	var prompt: TurnPrompt = _prompt(game)
	assert_eq(prompt.prompt, "Pick the AI's next colour.")
	assert_eq(prompt.detail, "That ends your turn. You can still guess first.")


func test_on_the_ai_s_turn_the_player_waits() -> void:
	var game: Match = _match(true)
	game.submit(AI, Command.pick_colour(BallColour.RED))
	game.submit(PLAYER, Command.place(Vector2i(0, 5)))
	game.submit(PLAYER, Command.pick_colour(BallColour.BLUE))
	assert_eq(_prompt(game).prompt, "The AI is thinking…")


func test_a_full_board_asks_for_the_forced_guess() -> void:
	var game: Match = Fixtures.nearly_full_match(_book)
	game.submit(PLAYER, Command.place(Fixtures.LAST_EMPTY_CELL))
	var prompt: TurnPrompt = _prompt(game)
	assert_has(["Guess or seal.", "Seal your guess."], prompt.prompt)
	assert_string_contains(prompt.detail, "The board is full.")


func test_nothing_once_the_match_is_over() -> void:
	var game: Match = _match(true)
	game.submit(AI, Command.pick_colour(BallColour.RED))
	game.submit(PLAYER, Command.guess("BT"))
	var prompt: TurnPrompt = _prompt(game)
	assert_eq(prompt.prompt, "")
	assert_eq(prompt.detail, "")
