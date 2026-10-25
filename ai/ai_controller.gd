class_name AIController
extends Controller

## The AI player. It sees only the PublicView it is handed (ADR 0002).
##
## Placeholder for milestone 1's first ticket: it places on a random legal cell
## and picks a random colour. Deduction, placement preference, colour-pick
## strategy and guessing replace these choices in later tickets.

var _rng: RandomNumberGenerator


## Every random choice goes through rng; seed it for reproducible play.
func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng


func decide(view: PublicView) -> Command:
	match view.phase:
		Match.Phase.FIRST_COLOUR, Match.Phase.PICK_COLOUR:
			return Command.pick_colour(_pick(BallColour.ALL))
		Match.Phase.PLACE:
			var cells: Array[Vector2i] = view.own_legal_cells()
			if cells.is_empty():
				return null
			return Command.place(_pick(cells))
	return null


func _pick(options: Array) -> Variant:
	return options[_rng.randi_range(0, options.size() - 1)]
