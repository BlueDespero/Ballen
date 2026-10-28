class_name Controller
extends RefCounted

## What human and AI players share: turn a PublicView into a Command.
##
## The driver asks every player in Match.awaiting_players() and always awaits:
##     var command: Command = await controller.decide(match.public_view(player))
##     match.submit(player, command)
## An AI returns at once; a human controller may wait for input (a coroutine),
## and the scene may add a pause before an AI acts. Return null for no command.


func decide(_view: PublicView) -> Command:
	return null
