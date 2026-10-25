class_name MatchDriver
extends RefCounted

## Plays a match: asks the controller of every player the match awaits for a
## command and submits it, until the match is over or a controller has no
## command. The match alone decides what is legal.
##
## The scene drives the player and the AI with it, redrawing on `changed`; it
## pauses the AI so the player can follow its turn. The harness can drive two
## AIs with no pause.

## The match accepted a command.
signal changed
## The player's controller returned no command, so the match can't go on.
## Until skips exist this happens when the player has no legal cell.
signal stalled(player: int)

## Bounds of the random pause before a paused player's command, in seconds.
const MIN_PAUSE: float = 0.5
const MAX_PAUSE: float = 1.5

var _match: Match
var _controllers: Array[Controller] = []
var _paused_players: Array[int] = []
var _rng: RandomNumberGenerator
var _wait: Callable


## controllers is indexed by player. Before each command of a player in
## paused_players the driver awaits wait.call(seconds), with seconds drawn
## from rng between MIN_PAUSE and MAX_PAUSE. The scene passes a timer; tests
## pass a function that only records the pause.
func _init(game: Match, controllers: Array[Controller], paused_players: Array[int], rng: RandomNumberGenerator, wait: Callable) -> void:
	_match = game
	_controllers = controllers.duplicate()
	_paused_players = paused_players.duplicate()
	_rng = rng
	_wait = wait


## Runs until the match is over or stalls. A coroutine: await it.
func run() -> void:
	while _match.phase() != Match.Phase.OVER:
		for player: int in _match.awaiting_players():
			if _paused_players.has(player):
				await _wait.call(_rng.randf_range(MIN_PAUSE, MAX_PAUSE))
			var command: Command = await _controllers[player].decide(_match.public_view(player))
			if command == null:
				stalled.emit(player)
				return
			if _match.submit(player, command):
				changed.emit()
