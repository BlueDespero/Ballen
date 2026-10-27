class_name MatchDriver
extends RefCounted

## Plays a match: asks the controller of every player the match awaits for a
## command and submits it, until the match is over, a controller gives up (has
## no command), or stop() is called. The match alone decides what is legal.
##
## The scene drives the player and the AI with it, redrawing on `changed`; it
## pauses the AI so the player can follow its turn, and holds the match while
## a skip is shown. Tests drive two AIs with no pause. The AI-vs-AI harness has
## its own loop (Harness.play_out): it needs no signals or awaits, and gives up
## on a rejected command instead of asking again.

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
var _skip_seconds: float
var _stopped: bool = false


## controllers is indexed by player. Before each command of a player in
## paused_players the driver awaits wait.call(seconds), with seconds drawn
## from rng between MIN_PAUSE and MAX_PAUSE. The scene passes a timer; tests
## pass a function that only records the pause.
## After a command that makes a player skip, the driver also awaits
## wait.call(skip_seconds), so the scene can show the skip before anyone acts
## again; with skip_seconds 0 it goes straight on.
func _init(current_match: Match, controllers: Array[Controller], paused_players: Array[int], rng: RandomNumberGenerator, wait: Callable, skip_seconds: float = 0.0) -> void:
	_match = current_match
	_controllers = controllers.duplicate()
	_paused_players = paused_players.duplicate()
	_rng = rng
	_wait = wait
	_skip_seconds = skip_seconds


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
			var events_before: int = _match.history().size()
			if _match.submit(player, command):
				changed.emit()
				if _skip_seconds > 0.0 and _skipped_since(events_before):
					await _wait.call(_skip_seconds)
					if _stopped:
						return


## Whether the history gained a skip after its first `first_new` events.
func _skipped_since(first_new: int) -> bool:
	var history: Array[HistoryEntry] = _match.history()
	for i: int in range(first_new, history.size()):
		if history[i].type == HistoryEntry.Type.SKIP:
			return true
	return false


## Ends run() at its next step: a pause or decision in progress submits
## nothing. The scene calls it when it closes.
func stop() -> void:
	_stopped = true
