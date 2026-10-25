class_name HumanController
extends Controller

## The person at the screen. decide() waits until the scene hands over the
## player's command with choose(): a ball dropped on a legal cell, a colour
## button pressed. The scene asks the match what is legal before choosing.

signal _chosen(command: Command)


func decide(view: PublicView) -> Command:
	# Until skips exist, a player with no legal cell has nothing to choose.
	if view.phase == Match.Phase.PLACE and view.own_legal_cells().is_empty():
		return null
	var command: Command = await _chosen
	return command


## The player's command for the decision in progress; ignored when none is.
## choose(null) gives up the decision (e.g. when the scene closes).
func choose(command: Command) -> void:
	_chosen.emit(command)
