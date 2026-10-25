extends GutTest

# PublicView (ADR 0002): an immutable snapshot per viewer, built by the match.

const Fixtures := preload("res://test/helpers/fixtures.gd")
const ObjectWalker := preload("res://test/helpers/object_walker.gd")

var _book: RuleBook


func before_each() -> void:
	_book = Fixtures.book()


## Player 0 holds R04 as true rule. Player 1's deck is [R04, B1..B4] and their
## true rule is the given one. Same seed, so the same coin toss.
func _match(opponent_true_rule_id: String) -> Match:
	var r04: Rule = _book.rule("R04")
	var deck_1: Deck = Fixtures.deck_with(_book, r04, "B")
	var opponent_true: Rule = deck_1.rules[0] if opponent_true_rule_id == "R04" else deck_1.rules[1]
	var decks: Array[Deck] = [Fixtures.deck_with(_book, r04, "A"), deck_1]
	var true_rules: Array[Rule] = [r04, opponent_true]
	return Match.create(decks, true_rules, Fixtures.rng(3))


## Plays the same inner-cell moves in any match; legal under R04 and B1.
func _play_some_turns(game: Match) -> void:
	var cells: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 3)]
	game.submit(game.current_player(), Command.pick_colour(BallColour.RED))
	for cell: Vector2i in cells:
		var player: int = game.current_player()
		assert_true(game.submit(player, Command.place(cell)))
		assert_true(game.submit(player, Command.pick_colour(BallColour.BLUE)))


func test_the_view_shows_the_viewers_own_true_rule_and_the_public_state() -> void:
	var game: Match = _match("R04")
	_play_some_turns(game)
	var view: PublicView = game.public_view(0)
	assert_eq(view.viewer, 0)
	assert_eq(view.own_true_rule.id, "R04")
	assert_eq(view.phase, game.phase())
	assert_eq(view.current_player, game.current_player())
	assert_eq(view.position.turn, game.turn())
	assert_eq(view.position.first_player, game.first_player())
	assert_eq(view.position.colour, BallColour.BLUE)
	assert_eq(view.position.skips, [0, 0] as Array[int])
	assert_eq(view.position.history.size(), 7)
	assert_eq(view.position.board.ball_at(Vector2i(2, 2)).colour, BallColour.BLUE)
	assert_eq(view.decks.size(), 2)
	assert_eq(view.decks[1].rules.size(), Deck.SIZE)
	assert_null(view.result, "no result while the match runs")


func test_the_view_is_the_same_whichever_opponent_rule_is_true() -> void:
	var with_r04: Match = _match("R04")
	var with_b1: Match = _match("B1")
	var commands: Array[Command] = [Command.pick_colour(BallColour.RED)]
	for cell: Vector2i in [Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 3), Vector2i(4, 4)]:
		commands.append(Command.place(cell))
		commands.append(Command.pick_colour(BallColour.GREEN))
	_assert_player_0_sees_the_same(with_r04, with_b1)
	for command: Command in commands:
		assert_true(with_r04.submit(with_r04.current_player(), command))
		assert_true(with_b1.submit(with_b1.current_player(), command))
		_assert_player_0_sees_the_same(with_r04, with_b1)


## Player 0's view never shows player 1's true rule or legal cells, so it is
## identical in two matches that differ only in player 1's true rule.
func _assert_player_0_sees_the_same(a: Match, b: Match) -> void:
	assert_eq_deep(ObjectWalker.dump(a.public_view(0)), ObjectWalker.dump(b.public_view(0)))
	var a_1: Dictionary = ObjectWalker.dump(a.public_view(1))
	var b_1: Dictionary = ObjectWalker.dump(b.public_view(1))
	assert_ne(a_1.own_true_rule, b_1.own_true_rule, "player 1 sees their own true rule")
	a_1.erase("own_true_rule")
	b_1.erase("own_true_rule")
	assert_eq_deep(a_1, b_1)


func test_the_view_holds_no_reference_back_to_the_match() -> void:
	var game: Match = _match("R04")
	_play_some_turns(game)
	for object: Object in ObjectWalker.objects(game.public_view(1)):
		assert_false(object is Match, "reached a Match from the view")
		assert_ne(object, game)


func test_changing_the_view_does_not_change_the_match() -> void:
	var game: Match = _match("R04")
	_play_some_turns(game)
	var view: PublicView = game.public_view(game.current_player())
	view.position.board.place(Vector2i(4, 4), Ball.new(BallColour.RED, 0))
	view.position.history.clear()
	view.position.skips[0] = 2
	view.decks[0].rules.clear()
	assert_true(game.is_legal(Vector2i(4, 4)))
	assert_eq(game.history().size(), 7)
	assert_eq(game.skip_count(0), 0)
	assert_eq(game.public_view(0).decks[0].rules.size(), Deck.SIZE)
