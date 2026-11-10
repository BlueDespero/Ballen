class_name PlacementStrategy
extends RefCounted

## Where the AI places its own ball, among the cells its secret rule allows.
## This base strategy hides the simple way: the cells that satisfy the most of
## its 5 deck rules, so any of them could be its secret rule; ties at random.
## Swappable: hand AIController a subclass (HidingPlacement, Normal's).

## No cell to place on.
const NO_CELL: Vector2i = Vector2i(-1, -1)

## For a strategy that thinks in steps (RolloutPlacement): stop working at
## about this Time.get_ticks_msec(), 0 for no limit; is_pending() then says
## whether choose() must be called again with the same view to finish.
var deadline_msec: int = 0


## True when the last choose() stopped at its deadline before deciding.
func is_pending() -> bool:
	return false


## The cell to place on; NO_CELL if the AI has none. exposure is the AI's
## belief about its own rules as the opponent could hold it.
func choose(view: PublicView, _exposure: Belief, rng: RandomNumberGenerator) -> Vector2i:
	return pick(most_shared(view, view.decks[view.viewer].rules), rng)


## The viewer's legal cells that the most of these rules allow.
static func most_shared(view: PublicView, rules: Array[Rule]) -> Array[Vector2i]:
	var best: Array[Vector2i] = []
	var best_count: int = -1
	var masks: Array[int] = []
	for rule: Rule in rules:
		masks.append(RuleChecker.legal_mask(rule, view.position, view.viewer, view.position.colour))
	for cell: Vector2i in view.own_legal_cells():
		var count: int = 0
		var bit: int = Board.bit(cell)
		for mask: int in masks:
			if mask & bit:
				count += 1
		if count > best_count:
			best = []
			best_count = count
		if count == best_count:
			best.append(cell)
	return best


static func pick(cells: Array[Vector2i], rng: RandomNumberGenerator) -> Vector2i:
	if cells.is_empty():
		return NO_CELL
	return cells[rng.randi_range(0, cells.size() - 1)]
