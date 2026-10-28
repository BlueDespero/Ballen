class_name HistoryEntry
extends RefCounted

## One event in a match's history; together they rebuild any past board.
## Treat an entry as an immutable value.
##
## To add an event: add a Type, a factory that fills the fields it uses, and a
## line in _to_string.

enum Type { PLACEMENT, COLOUR_PICK, GUESS, SKIP }

var type: Type
## Who acted: the placer, the player who picked the colour, the guesser, or the
## one who skipped.
var player: int
## PLACEMENT: where the ball went.
var cell: Vector2i
## PLACEMENT: the ball's colour. COLOUR_PICK: the colour picked for the opponent.
## SKIP: the colour of the ball that had no legal cell.
var colour: String
## GUESS: the id of the opponent's rule the guesser named.
var rule_id: String
## GUESS: whether that rule was the opponent's true rule.
var right: bool


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


static func guess(p_player: int, p_rule_id: String, p_right: bool) -> HistoryEntry:
	var entry: HistoryEntry = HistoryEntry.new(Type.GUESS, p_player)
	entry.rule_id = p_rule_id
	entry.right = p_right
	return entry


static func skip(p_player: int, p_colour: String) -> HistoryEntry:
	var entry: HistoryEntry = HistoryEntry.new(Type.SKIP, p_player)
	entry.colour = p_colour
	return entry


## Whether this is the board half of a turn: a placement, or the skip that
## takes its place. Every turn has exactly one; the other events (colour picks,
## guesses) leave the board alone.
func is_placement_or_skip() -> bool:
	return type == Type.PLACEMENT or type == Type.SKIP


func copy() -> HistoryEntry:
	var entry: HistoryEntry = HistoryEntry.new(type, player)
	entry.cell = cell
	entry.colour = colour
	entry.rule_id = rule_id
	entry.right = right
	return entry


func _to_string() -> String:
	match type:
		Type.PLACEMENT:
			return "player %d places %s at %s" % [player, colour, cell]
		Type.COLOUR_PICK:
			return "player %d picks %s" % [player, colour]
		Type.GUESS:
			return "player %d guesses %s, %s" % [player, rule_id, "right" if right else "wrong"]
		Type.SKIP:
			return "player %d skips %s" % [player, colour]
	return "player %d: event %d" % [player, type]
