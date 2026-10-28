class_name MatchDriver
extends RefCounted

## Plays a match: asks the controller of every player the match awaits for a
## command and submits it, until the match is over, a controller gives up (has
## no command), or stop() is called. The match alone decides what is legal.
##
## The scene drives the player and the AI with it, redrawing on `changed`; it
## pauses the AI so the player can follow its turn. Tests drive two AIs with
## no pause. The AI-vs-AI harness has its own loop (Harness.play_out): it
## needs no signals or awaits, and gives up on a rejected command instead of
## asking again.

## The match accepted a command.
signal changed

## Bounds of the random pause before a paused player's command, in seconds.
const MIN_PAUSE: float = 0.5
const MAX_PAUSE: float = 1.5

var _match: Match
var _controllers: Array[Controller] = []
var _paused_players: Array[int] = []
var _rng: RandomNumberGenerator
var _wait: Callable
var _stopped: bool = false


## controllers is indexed by player. Before each command of a player in
## paused_players the driver awaits wait.call(seconds), with seconds drawn
## from rng between MIN_PAUSE and MAX_PAUSE. The scene passes a timer; tests
## pass a function that only records the pause.
func _init(current_match: Match, controllers: Array[Controller], paused_players: Array[int], rng: RandomNumberGenerator, wait: Callable) -> void:
	_match = current_match
	_controllers = controllers.duplicate()
	_paused_players = paused_players.duplicate()
	_rng = rng
	_wait = wait


## Runs until the match is over, a controller gives up or the driver is
## stopped. A coroutine: await it.
## A command the match rejects changes nothing and the same player is asked
## again.
func run() -> void:
	while not _stopped and _match.phase() != Match.Phase.OVER:
		for player: int in _match.awaiting_players():
			if _paused_players.has(player):
				await _wait.call(_rng.randf_range(MIN_PAUSE, MAX_PAUSE))
				if _stopped:
					return
			var command: Command = await _controllers[player].decide(_match.public_view(player))
			if _stopped:
				return
			if command == null:
				return
			if _match.submit(player, command):
				changed.emit()


## Ends run() at its next step: a pause or decision in progress submits
## nothing. The scene calls it when it closes.
func stop() -> void:
	_stopped = true
