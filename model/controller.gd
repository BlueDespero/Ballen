class_name Controller
extends RefCounted

## What human and AI players share: turn a PublicView into a Command.
##
## The driver asks every player in Match.awaiting_players() and always awaits:
##     var command: Command = await controller.decide(match.public_view(player))
##     match.submit(player, command)
## An AI returns at once; a human controller may wait for input (a coroutine),
## and the scene may add a pause before an AI's command lands. Return null for
## no command.

## Bounds of the default pause, in seconds.
const MIN_PAUSE: float = 0.5
const MAX_PAUSE: float = 1.5


func decide(_view: PublicView) -> Command:
	return null


## True for a controller whose decisions take long enough to spread over
## frames: the driver then calls think_step() once a frame until it has a
## command, instead of decide().
func thinks_in_steps() -> bool:
	return false


## A slice of a decision, working until about deadline_msec
## (Time.get_ticks_msec()). Returns the command once decided; null while
## is_thinking() says more steps are needed (or for no command).
func think_step(view: PublicView, _deadline_msec: int) -> Command:
	return decide(view)


## True while the decision think_step() started is unfinished.
func is_thinking() -> bool:
	return false


## How long the scene should wait before the command decide() just returned
## lands, so a player can follow it. The default is a random 0.5–1.5 s; an AI
## scales it with how hard the choice was.
func pause_seconds(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(MIN_PAUSE, MAX_PAUSE)
