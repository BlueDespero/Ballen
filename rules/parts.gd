class_name Parts
extends RefCounted

## The parts that templates are built from (ADR 0001), and the evaluator that
## walks a template tree.
##
## A tree node is a Dictionary with a "part" key naming an entry of _parts; its
## other keys are the part's arguments. An argument is a literal, a nested node
## (under "of") or, in a template, a "$blank" placeholder that RuleBook fills
## with the rule's value before evaluation.
##
## Part kinds, by what they return:
## - selector: cells to look at (Array[Vector2i])
## - filter: the cells of its "of" node that count (Array[Vector2i])
## - condition: a pass / fail over cells (bool)
## - combiner: a pass / fail over its "of" list of conditions (bool)
## - group selector and group condition: see GroupParts (rules/group_parts.gd)
##
## To add a part: write a static function (node, ctx) -> value below and list it
## in _parts. JSON numbers arrive as floats, so read counts with int().

static var _parts: Dictionary[String, Callable] = {
	# Selectors
	"target": _target,
	"neighbours": _neighbours,
	"same_axis": _same_axis,
	"whole_board": _whole_board,
	# Filters
	"in_zone": _in_zone,
	"with_parity": _with_parity,
	"same_colour": _same_colour,
	"opponent_ball": _opponent_ball,
	"my_last_ball": _my_last_ball,
	"empty": _empty,
	"of_colour": _of_colour,
	# Conditions
	"count_at_most": _count_at_most,
	"count_at_least": _count_at_least,
	# Combiners
	"all": _all,
	"any": _any,
	# Group parts (rules/group_parts.gd)
	"lines_through": GroupParts.lines_through,
	"no_group_of": GroupParts.no_group_of,
}


static func has_part(part: String) -> bool:
	return _parts.has(part)


static func evaluate(node: Dictionary, ctx: PlacementContext) -> Variant:
	var part: Callable = _parts[node.part]
	return part.call(node, ctx)


static func _cells(node: Dictionary, ctx: PlacementContext) -> Array[Vector2i]:
	return evaluate(node, ctx)


# Selectors ------------------------------------------------------------------

## The target cell. {"part": "target"}
static func _target(_node: Dictionary, ctx: PlacementContext) -> Array[Vector2i]:
	return [ctx.target]


## The neighbours (up to 8, diagonals included, on the board only) of the cells
## of "of", each listed once, leaving out the cells of "of" themselves.
## {"part": "neighbours", "of": {"part": "target"}}
static func _neighbours(node: Dictionary, ctx: PlacementContext) -> Array[Vector2i]:
	var centres: Array[Vector2i] = _cells(node.of, ctx)
	var cells: Array[Vector2i] = []
	for centre: Vector2i in centres:
		for cell: Vector2i in Board.neighbours(centre):
			if not centres.has(cell) and not cells.has(cell):
				cells.append(cell)
	return cells


## Every cell in the same row as a cell of "of", the "of" cells included, each
## listed once. {"part": "same_axis", "axis": "row", "of": {"part": "target"}}
## Axes: "row".
static func _same_axis(node: Dictionary, ctx: PlacementContext) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if node.axis != "row":
		push_error("same_axis: unknown axis '%s'" % node.axis)
		return cells
	for centre: Vector2i in _cells(node.of, ctx):
		for x: int in Board.SIZE:
			var cell: Vector2i = Vector2i(x, centre.y)
			if not cells.has(cell):
				cells.append(cell)
	return cells


## Every cell of the board. {"part": "whole_board"}
static func _whole_board(_node: Dictionary, _ctx: PlacementContext) -> Array[Vector2i]:
	return Board.all_cells()


# Filters --------------------------------------------------------------------

## Cells in a zone of the board. {"part": "in_zone", "zone": "edge", "of": ...}
## Zones: "edge" (the outer ring).
static func _in_zone(node: Dictionary, ctx: PlacementContext) -> Array[Vector2i]:
	var kept: Array[Vector2i] = []
	for cell: Vector2i in _cells(node.of, ctx):
		match node.zone:
			"edge":
				if Board.is_on_edge(cell):
					kept.append(cell)
			_:
				push_error("in_zone: unknown zone '%s'" % node.zone)
	return kept


## Cells whose row number (1-6 from the first player's side) is even or odd.
## Columns are not numbered, so "row" is the only axis.
## {"part": "with_parity", "axis": "row", "parity": "even", "of": ...}
static func _with_parity(node: Dictionary, ctx: PlacementContext) -> Array[Vector2i]:
	var kept: Array[Vector2i] = []
	if node.axis != "row":
		push_error("with_parity: unknown axis '%s'" % node.axis)
		return kept
	var remainder: int = 0 if node.parity == "even" else 1
	for cell: Vector2i in _cells(node.of, ctx):
		if Board.row_number(cell, ctx.position.first_player) % 2 == remainder:
			kept.append(cell)
	return kept


## Cells holding a ball of the placed ball's colour, either owner.
## {"part": "same_colour", "of": ...}
static func _same_colour(node: Dictionary, ctx: PlacementContext) -> Array[Vector2i]:
	var kept: Array[Vector2i] = []
	for cell: Vector2i in _cells(node.of, ctx):
		var ball: Ball = ctx.board.ball_at(cell)
		if ball != null and ball.colour == ctx.colour:
			kept.append(cell)
	return kept


## Cells holding a ball owned by the holder's opponent, any colour.
## {"part": "opponent_ball", "of": ...}
static func _opponent_ball(node: Dictionary, ctx: PlacementContext) -> Array[Vector2i]:
	var kept: Array[Vector2i] = []
	var opponent: int = Players.opponent(ctx.holder)
	for cell: Vector2i in _cells(node.of, ctx):
		var ball: Ball = ctx.board.ball_at(cell)
		if ball != null and ball.owner == opponent:
			kept.append(cell)
	return kept


## The cell of the holder's last ball, when it is among the cells of "of";
## nothing before the holder's first placement.
## {"part": "my_last_ball", "of": ...}
static func _my_last_ball(node: Dictionary, ctx: PlacementContext) -> Array[Vector2i]:
	var kept: Array[Vector2i] = []
	var last: Array[Vector2i] = ctx.last_ball(ctx.holder)
	for cell: Vector2i in _cells(node.of, ctx):
		if last.has(cell):
			kept.append(cell)
	return kept


## Cells holding no ball (after the placement, so never the target).
## {"part": "empty", "of": ...}
static func _empty(node: Dictionary, ctx: PlacementContext) -> Array[Vector2i]:
	var kept: Array[Vector2i] = []
	for cell: Vector2i in _cells(node.of, ctx):
		if ctx.board.is_empty(cell):
			kept.append(cell)
	return kept


## Cells holding a ball of a fixed colour, either owner. The target holds the
## placed ball, so of_colour over the target keeps it exactly when a ball of
## that colour is placed. {"part": "of_colour", "colour": "red", "of": ...}
static func _of_colour(node: Dictionary, ctx: PlacementContext) -> Array[Vector2i]:
	var kept: Array[Vector2i] = []
	for cell: Vector2i in _cells(node.of, ctx):
		var ball: Ball = ctx.board.ball_at(cell)
		if ball != null and ball.colour == node.colour:
			kept.append(cell)
	return kept


# Conditions -----------------------------------------------------------------

## At most n cells. {"part": "count_at_most", "n": 0, "of": ...}
static func _count_at_most(node: Dictionary, ctx: PlacementContext) -> bool:
	return _cells(node.of, ctx).size() <= int(node.n)


## At least n cells. {"part": "count_at_least", "n": 2, "of": ...}
static func _count_at_least(node: Dictionary, ctx: PlacementContext) -> bool:
	return _cells(node.of, ctx).size() >= int(node.n)


# Combiners ------------------------------------------------------------------

## Passes when every condition passes; an empty list always passes, which makes
## {"part": "all", "of": []} a permissive rule for tests.
## {"part": "all", "of": [<condition>, ...]}
static func _all(node: Dictionary, ctx: PlacementContext) -> bool:
	for condition: Dictionary in node.of:
		if not evaluate(condition, ctx):
			return false
	return true


## Passes when at least one condition passes; an empty list never passes.
## {"part": "any", "of": [<condition>, ...]}
static func _any(node: Dictionary, ctx: PlacementContext) -> bool:
	for condition: Dictionary in node.of:
		if evaluate(condition, ctx):
			return true
	return false
