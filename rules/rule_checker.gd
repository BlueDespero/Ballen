class_name RuleChecker
extends RefCounted

## Answers whether a rule allows a placement, and which cells it allows.
## This is the one source of legality for the match, the UI and the AI.


## True when the cell is empty and the rule passes for its holder placing a
## ball of this colour there.
static func is_legal(rule: Rule, position: MatchPosition, holder: int, colour: String, cell: Vector2i) -> bool:
	if not position.board.is_empty(cell):
		return false
	return rule.passes(PlacementContext.new(position, holder, colour, cell))


## The empty cells where the rule allows its holder to place a ball of this colour.
static func legal_cells(rule: Rule, position: MatchPosition, holder: int, colour: String) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in position.board.empty_cells():
		if rule.passes(PlacementContext.new(position, holder, colour, cell)):
			cells.append(cell)
	return cells
