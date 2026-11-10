class_name RuleChecker
extends RefCounted

## Answers whether a rule allows a placement, and which cells it allows.
## This is the one source of legality for the match, the UI and the AI.
##
## It answers from the rule's compiled bit-mask form (RuleCompiler, ADR 0003).
## A rule that can't be compiled is interpreted (Parts); the interpreted
## answers are also the reference the compiled ones are tested against.


## True when the cell is empty and the rule passes for its holder placing a
## ball of this colour there.
static func is_legal(rule: Rule, position: MatchPosition, holder: int, colour: String, cell: Vector2i) -> bool:
	if not position.board.is_empty(cell):
		return false
	return legal_mask(rule, position, holder, colour) & Board.bit(cell) != 0


## The empty cells where the rule allows its holder to place a ball of this colour.
static func legal_cells(rule: Rule, position: MatchPosition, holder: int, colour: String) -> Array[Vector2i]:
	return Board.cells_of(legal_mask(rule, position, holder, colour))


## legal_cells as a cell mask (Board.bit): one bit per allowed cell.
static func legal_mask(rule: Rule, position: MatchPosition, holder: int, colour: String) -> int:
	var compiled: RuleCompiler.CompiledRule = rule.compiled()
	if compiled != null:
		return compiled.legal_mask(position, holder, colour)
	return interpreted_legal_mask(rule, position, holder, colour)


## is_legal by walking the rule's tree (Parts), cell by cell.
static func interpreted_is_legal(rule: Rule, position: MatchPosition, holder: int, colour: String, cell: Vector2i) -> bool:
	if not position.board.is_empty(cell):
		return false
	return rule.passes(PlacementContext.new(position, holder, colour, cell))


## legal_mask by walking the rule's tree (Parts) for each empty cell. One
## scratch copy of the board serves every cell: the ball is placed on it, the
## rule judged, and the ball lifted again (parts never keep the board). Counts
## that are the same for every cell are worked out once per call.
static func interpreted_legal_mask(rule: Rule, position: MatchPosition, holder: int, colour: String) -> int:
	var mask: int = 0
	var board: Board = position.board.copy()
	var ball: Ball = Ball.new(colour, holder)
	var cache: Dictionary = {}
	for cell: Vector2i in position.board.empty_cells():
		board.place(cell, ball)
		if rule.passes(PlacementContext.new(position, holder, colour, cell, board, cache)):
			mask |= Board.bit(cell)
		board.remove(cell)
	return mask
