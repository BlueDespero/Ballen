class_name Command
extends RefCounted

## An action a player sends to the match with Match.submit(player, command).
##
## To add a command: add a Type, a factory below with its payload, and a
## handler in Match.submit that checks the phase.

enum Type { PLACE, PICK_COLOUR }

var type: Type
## PLACE: the target cell.
var cell: Vector2i
## PICK_COLOUR: the colour the opponent places next.
var colour: String


func _init(p_type: Type) -> void:
	type = p_type


## Put the current ball on a legal cell.
static func place(p_cell: Vector2i) -> Command:
	var command: Command = Command.new(Type.PLACE)
	command.cell = p_cell
	return command


## Pick the colour the opponent places next; ends the turn.
static func pick_colour(p_colour: String) -> Command:
	var command: Command = Command.new(Type.PICK_COLOUR)
	command.colour = p_colour
	return command


func _to_string() -> String:
	match type:
		Type.PLACE:
			return "place %s" % cell
		Type.PICK_COLOUR:
			return "pick %s" % colour
	return "command %d" % type
