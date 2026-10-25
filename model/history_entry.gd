class_name HistoryEntry
extends RefCounted

## One event in a match's move history; together they rebuild any past board.
## Treat an entry as an immutable value.
##
## To add an event: add a Type, a factory that fills the fields it uses, and a
## line in _to_string.

enum Type { PLACEMENT, COLOUR_PICK }

var type: Type
## Who acted: the placer, or the player who picked the colour.
var player: int
## PLACEMENT: where the ball went.
var cell: Vector2i
## PLACEMENT: the ball's colour. COLOUR_PICK: the colour picked for the opponent.
var colour: String


func _init(p_type: Type, p_player: int) -> void:
	type = p_type
	player = p_player


static func placement(p_player: int, p_cell: Vector2i, p_colour: String) -> HistoryEntry:
	var entry: HistoryEntry = HistoryEntry.new(Type.PLACEMENT, p_player)
	entry.cell = p_cell
	entry.colour = p_colour
	return entry


static func colour_pick(p_player: int, p_colour: String) -> HistoryEntry:
	var entry: HistoryEntry = HistoryEntry.new(Type.COLOUR_PICK, p_player)
	entry.colour = p_colour
	return entry


func copy() -> HistoryEntry:
	var entry: HistoryEntry = HistoryEntry.new(type, player)
	entry.cell = cell
	entry.colour = colour
	return entry


func _to_string() -> String:
	match type:
		Type.PLACEMENT:
			return "player %d places %s at %s" % [player, colour, cell]
		Type.COLOUR_PICK:
			return "player %d picks %s" % [player, colour]
	return "player %d: event %d" % [player, type]
