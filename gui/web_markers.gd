extends Node

## Console markers for the Playwright web tests (`web-test/`). The canvas has
## no DOM to inspect, so in web builds only the game prints a line such as
## `[ballen] scene=Main` on scene changes and key events, and the tests wait
## for them. Other builds print nothing. The `WebMarkers` autoload.
##
## Some markers measure whether players understand the game, for playtests to
## compare before and after a change: how long the secret-rule pick took and
## whether Pick for me made it, the turn and result of each guess, and Guess
## presses made before selecting a rule.

const PREFIX: String = "[ballen]"


## One marker line: the prefix, the event, then `key=value` fields in order.
static func line(event: String, fields: Dictionary = {}) -> String:
	var parts: PackedStringArray = [PREFIX, event]
	for key: Variant in fields:
		parts.append("%s=%s" % [key, fields[key]])
	return " ".join(parts)


static func scene_line(scene_name: String) -> String:
	return line("scene=" + scene_name)


static func match_started_line(player_goes_first: bool) -> String:
	return line("match_started", {"first": "player" if player_goes_first else "ai"})


static func ball_placed_line(by_player: bool, cell: Vector2i) -> String:
	return line("ball_placed", {"by": "player" if by_player else "ai", "cell": "%d,%d" % [cell.x, cell.y]})


static func colour_picked_line(by_player: bool, colour: String) -> String:
	return line("colour_picked", {"by": "player" if by_player else "ai", "colour": colour})


static func deck_saved_line(deck_name: String) -> String:
	return line("deck_saved", {"name": deck_name})


static func decks_line(deck_names: Array[String]) -> String:
	return line("decks=" + ",".join(deck_names))


static func secret_rule_line(rule_id: String, seconds: float, picked_for_me: bool) -> String:
	return line("secret_rule", {"rule": rule_id, "seconds": "%.1f" % seconds, "picked_for_me": picked_for_me})


static func guess_line(by_player: bool, turn: int, right: bool) -> String:
	return line("guess", {"by": "player" if by_player else "ai", "turn": turn, "right": right})


static func guess_blocked_line() -> String:
	return line("guess_blocked")


func _ready() -> void:
	if not OS.has_feature("web"):
		return
	get_tree().scene_changed.connect(_print_scene)
	EventBus.match_started.connect(func(first: bool) -> void: print(match_started_line(first)))
	EventBus.ball_placed.connect(func(by_player: bool, cell: Vector2i) -> void: print(ball_placed_line(by_player, cell)))
	EventBus.colour_picked.connect(func(by_player: bool, colour: String) -> void: print(colour_picked_line(by_player, colour)))
	EventBus.deck_saved.connect(func(deck_name: String) -> void: print(deck_saved_line(deck_name)))
	EventBus.decks_listed.connect(func(deck_names: Array[String]) -> void: print(decks_line(deck_names)))
	EventBus.secret_rule_picked.connect(
		func(rule_id: String, seconds: float, mine: bool) -> void: print(secret_rule_line(rule_id, seconds, mine)))
	EventBus.guessed.connect(func(by_player: bool, turn: int, right: bool) -> void: print(guess_line(by_player, turn, right)))
	EventBus.guess_blocked.connect(func() -> void: print(guess_blocked_line()))
	# The first scene is set after the autoloads are ready.
	await get_tree().process_frame
	_print_scene()


func _print_scene() -> void:
	var scene: Node = get_tree().current_scene
	if scene != null:
		print(scene_line(scene.name))
