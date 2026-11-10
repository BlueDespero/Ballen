class_name RuleCompiler
extends RefCounted

## Compiles a filled rule tree (ADR 0001) into bit-mask form (ADR 0003): the
## cells a rule allows for one placement check, all at once, from the board's
## cell masks (Board.colour_mask and friends) instead of judging each cell by
## walking the tree. The Parts interpreter stays the reference: the compiled
## form must give exactly the cells it gives (test_rule_compiler.gd).
##
## Supports every part a built-in template uses, in the shapes the templates
## use them: selectors around the target, any chain of filters, counts, the
## combiners, the time and game-state conditions, rows relative to a last ball
## and lines through the target. compile() returns null for a tree it can't
## compile, and RuleChecker then interprets that rule.

## Filters that keep balls by what they are. The value says whether the placed
## ball can pass: "yes", "no", or "colour" (it passes when it has that colour).
const _BALL_FILTERS: Dictionary[String, String] = {
	"of_colour": "colour",
	"same_colour": "yes",
	"my_ball": "yes",
	"opponent_ball": "no",
	"any_ball": "yes",
	"next_colour": "no",
	"empty": "no",
	"my_last_ball": "no",
	"opponent_last_ball": "no",
}
const _CELL_FILTERS: Array[String] = ["in_zone", "with_parity", "in_rows", "in_row_relative"]
## Selectors and whether the cells they pick around the target include it.
const _SELECTORS: Dictionary[String, bool] = {
	"target": true,
	"neighbours": false,
	"same_axis": true,
	"whole_board": true,
	"other_cells": false,
	"within_distance": false,
}


## The compiled rule, or null if the tree uses a part or shape not supported.
static func compile(tree: Dictionary) -> CompiledRule:
	var root: Condition = _condition(tree)
	return CompiledRule.new(root) if root != null else null


static func _condition(node: Variant) -> Condition:
	if not node is Dictionary:
		return null
	match node.get("part", ""):
		"count_at_most", "count_at_least":
			var cells: Cells = _cells(node.of)
			if cells == null:
				return null
			return CountCondition.new(cells, node.part == "count_at_least", int(node.n))
		"no_more_than":
			var cells_of: Cells = _cells(node.of)
			var cells_than: Cells = _cells(node.than)
			if cells_of == null or cells_than == null:
				return null
			return NoMoreThan.new(cells_of, cells_than)
		"all", "any":
			var conditions: Array[Condition] = []
			for child: Variant in node.of:
				var condition: Condition = _condition(child)
				if condition == null:
					return null
				conditions.append(condition)
			return Combined.new(node.part == "all", conditions)
		"if_then":
			var condition_if: Condition = _condition(node["if"])
			var condition_then: Condition = _condition(node["then"])
			if condition_if == null or condition_then == null:
				return null
			return IfThen.new(condition_if, condition_then)
		"own_turn_parity":
			return GameState.new("own_turn_parity", 0 if node.parity == "even" else 1)
		"own_turn_at_most":
			return GameState.new("own_turn_at_most", int(node.n))
		"skips_at_least":
			return GameState.new("skips_at_least", int(node.n))
		"no_group_of":
			var groups: Variant = node.of
			if not groups is Dictionary or groups.get("part", "") != "lines_through" or not _is_target(groups.of):
				return null
			return NoLine.new(int(node.n))
	return null


## The cells of a cell-list node: a selector around the target under a chain
## of filters; null if not of that shape.
static func _cells(node: Variant) -> Cells:
	if not node is Dictionary:
		return null
	var part: String = node.get("part", "")
	if _SELECTORS.has(part):
		if part != "target" and part != "whole_board" and not _is_target(node.of):
			return null
		if part == "same_axis" and node.axis != "row":
			return null
		return Cells.new(part, int(node.get("n", 0)))
	if _BALL_FILTERS.has(part) or _CELL_FILTERS.has(part):
		var inner: Cells = _cells(node.of)
		if inner == null:
			return null
		var filter: Dictionary = node.duplicate()
		filter.erase("of")
		if part == "in_row_relative":
			var than: Cells = _cells(node.than)
			# The rows compared with must not depend on where the ball goes: the
			# placed ball can't be among them, and they come from the board.
			if than == null or not than.never_depend_on_target() or not ["whole_board", "other_cells"].has(than.selector):
				return null
			if node.direction != "higher" and node.direction != "lower":
				return null
			filter.than = than
		elif part == "in_zone" and node.zone != "edge":
			return null
		elif (part == "with_parity") and node.axis != "row":
			return null
		inner.filters.append(filter)
		return inner
	return null


static func _is_target(node: Variant) -> bool:
	return node is Dictionary and node.get("part", "") == "target"


## One placement check: who places which colour on which position.
class Check:
	var position: MatchPosition
	var board: Board
	var holder: int
	var colour: String
	var empty: int
	var last_balls: Array[int] = [0, 0]

	func _init(p_position: MatchPosition, p_holder: int, p_colour: String) -> void:
		position = p_position
		board = p_position.board
		holder = p_holder
		colour = p_colour
		empty = CellMasks.ALL & ~board.occupied_mask()
		for player: int in Players.COUNT:
			var entry: HistoryEntry = position.last_placement(player)
			if entry != null:
				last_balls[player] = Board.bit(entry.cell)


## A rule compiled: the cells it allows for one placement check.
class CompiledRule:
	var _root: Condition

	func _init(root: Condition) -> void:
		_root = root

	## The empty cells where the rule allows its holder to place a ball of
	## this colour, as a cell mask.
	func legal_mask(position: MatchPosition, holder: int, colour: String) -> int:
		var check: Check = Check.new(position, holder, colour)
		return _root.mask(check) & check.empty


## A pass / fail, as the mask of the targets where it passes.
class Condition:
	func mask(_check: Check) -> int:
		return 0


## The cells a selector picks around the target, kept by its filters. Never
## changed after compiling (ADR 0002: a rule keeps no trace of its use);
## prepare() works out one check's masks in a new Counted.
class Cells:
	var selector: String
	var n: int
	var filters: Array[Dictionary] = []
	var includes_target: bool
	## For each cell index, the cells the selector picks around it (for the
	## selectors that need a table).
	var tables: Array[int] = []

	func _init(p_selector: String, p_n: int) -> void:
		selector = p_selector
		n = p_n
		includes_target = RuleCompiler._SELECTORS[selector]
		if selector == "neighbours":
			tables = CellMasks.neighbours
		elif selector == "within_distance":
			tables = CellMasks.within(n)
		elif selector == "same_axis":
			tables = CellMasks.row_of

	## True when the cells never depend on where the ball goes: some filter
	## always turns the placed ball away, and none keeps empty cells (the
	## target is empty before the placement and full after it).
	func never_depend_on_target() -> bool:
		var turns_placed_away: bool = false
		for filter: Dictionary in filters:
			if filter.part == "empty":
				return false
			if RuleCompiler._BALL_FILTERS.get(filter.part, "") == "no":
				turns_placed_away = true
		return turns_placed_away

	func prepare(check: Check) -> Counted:
		var kept: int = CellMasks.ALL
		var places: int = CellMasks.ALL
		var placed_passes: bool = true
		var board: Board = check.board
		var opponent: int = Players.opponent(check.holder)
		var first_player: int = check.position.first_player
		for filter: Dictionary in filters:
			match filter.part:
				"of_colour":
					kept &= board.colour_mask(filter.colour)
					placed_passes = placed_passes and check.colour == filter.colour
				"same_colour":
					kept &= board.colour_mask(check.colour)
				"my_ball":
					kept &= board.owner_mask(check.holder)
				"opponent_ball":
					kept &= board.owner_mask(opponent)
				"any_ball":
					kept &= board.occupied_mask()
				"next_colour":
					kept &= board.colour_mask(Parts.next_colour_after(check.colour))
				"empty":
					kept &= check.empty
				"my_last_ball":
					kept &= check.last_balls[check.holder]
				"opponent_last_ball":
					kept &= check.last_balls[opponent]
				"in_zone":
					places &= CellMasks.edge
				"with_parity":
					places &= CellMasks.rows_with_parity(first_player, 0 if filter.parity == "even" else 1)
				"in_rows":
					places &= CellMasks.rows_between(first_player, int(filter.from), int(filter.to))
				"in_row_relative":
					places &= _rows_beyond(filter, check)
			if RuleCompiler._BALL_FILTERS.get(filter.part, "") == "no":
				placed_passes = false
		return Counted.new(self, kept & places, places, placed_passes)

	func is_around_target() -> bool:
		return selector == "neighbours" or selector == "within_distance"

	func _rows_beyond(filter: Dictionary, check: Check) -> int:
		var than: Cells = filter.than
		var references: int = than.prepare(check).kept
		if references == 0:
			return CellMasks.ALL
		var first_player: int = check.position.first_player
		var highest: int = 0
		var lowest: int = Board.SIZE + 1
		for cell: Vector2i in Board.cells_of(references):
			var row: int = Board.row_number(cell, first_player)
			highest = maxi(highest, row)
			lowest = mini(lowest, row)
		if filter.direction == "higher":
			return CellMasks.rows_between(first_player, highest + 1, Board.SIZE)
		return CellMasks.rows_between(first_player, 1, lowest - 1)


## Cells worked out for one check: count_at(target) counts them for any target.
class Counted:
	var cells: Cells
	## The cells other than the target that the filters keep.
	var kept: int
	## The cells whose place passes the cell filters.
	var places: int
	## Whether the placed ball itself passes the ball filters.
	var placed_passes: bool
	var _count: int

	func _init(p_cells: Cells, p_kept: int, p_places: int, p_placed_passes: bool) -> void:
		cells = p_cells
		kept = p_kept
		places = p_places
		placed_passes = p_placed_passes
		_count = CellMasks.popcount(kept)

	## How many of the cells there are when the ball is placed on target (a
	## cell index); the target counts when the selector includes it, its place
	## passes and the placed ball passes.
	func count_at(target: int) -> int:
		var bit: int = 1 << target
		var count: int = 0
		match cells.selector:
			"target":
				pass
			"whole_board", "other_cells":
				count = _count - (1 if kept & bit else 0)
			"same_axis":
				count = CellMasks.popcount(cells.tables[target] & kept & ~bit)
			_:
				count = CellMasks.popcount(cells.tables[target] & kept)
		if cells.includes_target and placed_passes and places & bit:
			count += 1
		return count

	## The targets whose cells hold at least one cell (for the selectors that
	## leave the target out), without counting each.
	func touching() -> int:
		return CellMasks.spread(kept, cells.tables)


class CountCondition extends Condition:
	var _cells: Cells
	var _at_least: bool
	var _n: int

	func _init(cells: Cells, at_least: bool, n: int) -> void:
		_cells = cells
		_at_least = at_least
		_n = n

	func mask(check: Check) -> int:
		var counted: Counted = _cells.prepare(check)
		if _cells.selector == "target":
			var one: int = counted.places if counted.placed_passes else 0
			return (CellMasks.ALL & ~one if _passes(0) else 0) | (one if _passes(1) else 0)
		if _cells.is_around_target():
			if _at_least and _n <= 1:
				return CellMasks.ALL if _n <= 0 else counted.touching()
			if not _at_least and _n == 0:
				return CellMasks.ALL & ~counted.touching()
		var result: int = 0
		var targets: int = check.empty
		var index: int = 0
		while targets != 0:
			if targets & 1 and _passes(counted.count_at(index)):
				result |= 1 << index
			targets >>= 1
			index += 1
		return result

	func _passes(count: int) -> bool:
		return count >= _n if _at_least else count <= _n


class NoMoreThan extends Condition:
	var _of: Cells
	var _than: Cells

	func _init(cells_of: Cells, cells_than: Cells) -> void:
		_of = cells_of
		_than = cells_than

	func mask(check: Check) -> int:
		var counted_of: Counted = _of.prepare(check)
		var counted_than: Counted = _than.prepare(check)
		var result: int = 0
		var targets: int = check.empty
		var index: int = 0
		while targets != 0:
			if targets & 1 and counted_of.count_at(index) <= counted_than.count_at(index):
				result |= 1 << index
			targets >>= 1
			index += 1
		return result


class Combined extends Condition:
	var _all: bool
	var _conditions: Array[Condition]

	func _init(all: bool, conditions: Array[Condition]) -> void:
		_all = all
		_conditions = conditions

	func mask(check: Check) -> int:
		var result: int = CellMasks.ALL if _all else 0
		for condition: Condition in _conditions:
			if _all:
				result &= condition.mask(check)
			else:
				result |= condition.mask(check)
		return result


class IfThen extends Condition:
	var _if: Condition
	var _then: Condition

	func _init(condition_if: Condition, condition_then: Condition) -> void:
		_if = condition_if
		_then = condition_then

	func mask(check: Check) -> int:
		return (CellMasks.ALL & ~_if.mask(check)) | _then.mask(check)


## A condition on the turn or the skips, the same for every target.
class GameState extends Condition:
	var _kind: String
	var _value: int

	func _init(kind: String, value: int) -> void:
		_kind = kind
		_value = value

	func mask(check: Check) -> int:
		var passes: bool = false
		match _kind:
			"own_turn_parity":
				passes = PlacementContext.own_turn_of(check.position, check.holder) % 2 == _value
			"own_turn_at_most":
				passes = PlacementContext.own_turn_of(check.position, check.holder) <= _value
			"skips_at_least":
				var total: int = 0
				for count: int in check.position.skips:
					total += count
				passes = total >= _value
		return CellMasks.ALL if passes else 0


## No straight line (any direction) of n or more balls of the placed colour
## through the target, once the ball is there.
class NoLine extends Condition:
	const DIRECTIONS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]
	var _n: int

	func _init(n: int) -> void:
		_n = n

	func mask(check: Check) -> int:
		if _n <= 1:
			return 0
		var same: int = check.board.colour_mask(check.colour)
		var lined: int = 0
		for direction: Vector2i in DIRECTIONS:
			# The target at place a of a run of n: the other n - 1 cells hold the colour.
			for a: int in _n:
				var window: int = CellMasks.ALL
				for j: int in _n:
					if j != a:
						window &= CellMasks.shifted(same, (j - a) * direction.x, (j - a) * direction.y)
				lined |= window
		return CellMasks.ALL & ~lined
