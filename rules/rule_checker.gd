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
## One scratch copy of the board serves every cell: the ball is placed on it,
## the rule judged, and the ball lifted again (parts never keep the board).
## Counts that are the same for every cell are worked out once per call.
static func legal_cells(rule: Rule, position: MatchPosition, holder: int, colour: String) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var board: Board = position.board.copy()
	var ball: Ball = Ball.new(colour, holder)
	var cache: Dictionary = {}
	for cell: Vector2i in position.board.empty_cells():
		board.place(cell, ball)
		if rule.passes(PlacementContext.new(position, holder, colour, cell, board, cache)):
			cells.append(cell)
		board.remove(cell)
	return cells
