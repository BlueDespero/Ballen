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
##
## To add a part: write a static function (node, ctx) -> value below and list it
## in _parts. JSON numbers arrive as floats, so read counts with int().

static var _parts: Dictionary[String, Callable] = {
	# Selectors
	"target": _target,
	# Filters
	"in_zone": _in_zone,
	# Conditions
	"count_at_most": _count_at_most,
	# Combiners
	"all": _all,
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


# Conditions -----------------------------------------------------------------

## At most n cells. {"part": "count_at_most", "n": 0, "of": ...}
static func _count_at_most(node: Dictionary, ctx: PlacementContext) -> bool:
	return _cells(node.of, ctx).size() <= int(node.n)


# Combiners ------------------------------------------------------------------

## Passes when every condition passes; an empty list always passes, which makes
## {"part": "all", "of": []} a permissive rule for tests.
## {"part": "all", "of": [<condition>, ...]}
static func _all(node: Dictionary, ctx: PlacementContext) -> bool:
	for condition: Dictionary in node.of:
		if not evaluate(condition, ctx):
			return false
	return true
