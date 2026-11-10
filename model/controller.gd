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


## How long the scene should wait before the command decide() just returned
## lands, so a player can follow it. The default is a random 0.5–1.5 s; an AI
## scales it with how hard the choice was.
func pause_seconds(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(MIN_PAUSE, MAX_PAUSE)
