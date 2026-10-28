class_name GroupParts
extends RefCounted

## Parts that work on groups of cells rather than on single cells (ADR 0001).
## Registered in Parts._parts like every other part.
##
## A group is an Array[Vector2i]; a group selector returns an Array of groups.
## - group selector: groups of cells to look at (Array of Array[Vector2i])
## - group condition: a pass / fail over the groups of its "of" node (bool)

## The four straight directions: horizontal, vertical and both diagonals.
const DIRECTIONS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]


# Group selectors ------------------------------------------------------------

## For each cell of "of" that holds a ball, the lines through it: one group per
## direction (horizontal, vertical and both diagonals) with the unbroken
## straight stretch of balls of that ball's colour, either owner, that contains
## the cell. Cells are in order along the direction; a lone ball gives a group
## of 1. Empty cells give no groups. {"part": "lines_through", "of": ...}
static func lines_through(node: Dictionary, ctx: PlacementContext) -> Array:
	var groups: Array = []
	for cell: Vector2i in Parts._cells(node.of, ctx):
		var ball: Ball = ctx.board.ball_at(cell)
		if ball == null:
			continue
		for direction: Vector2i in DIRECTIONS:
			groups.append(_line(ctx.board, cell, direction, ball.colour))
	return groups


# Group conditions -----------------------------------------------------------

## Passes when no group of "of" holds n or more cells.
## {"part": "no_group_of", "n": 3, "of": <group selector>}
static func no_group_of(node: Dictionary, ctx: PlacementContext) -> bool:
	var groups: Array = Parts.evaluate(node.of, ctx)
	for group: Array[Vector2i] in groups:
		if group.size() >= int(node.n):
			return false
	return true


# The unbroken stretch of balls of this colour through the cell along the direction.
static func _line(board: Board, cell: Vector2i, direction: Vector2i, colour: String) -> Array[Vector2i]:
	var start: Vector2i = cell
	while _has_colour(board, start - direction, colour):
		start -= direction
	var line: Array[Vector2i] = []
	var current: Vector2i = start
	while _has_colour(board, current, colour):
		line.append(current)
		current += direction
	return line


static func _has_colour(board: Board, cell: Vector2i, colour: String) -> bool:
	var ball: Ball = board.ball_at(cell)
	return ball != null and ball.colour == colour
