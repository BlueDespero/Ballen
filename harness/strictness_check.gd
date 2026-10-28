class_name StrictnessCheck
extends RefCounted

## The strictness check: how much of the board a rule forbids, measured as the
## share of empty cells it rules out for its holder, averaged over seeded
## random positions (random_positions). The rule tiers combine it with the
## AI-vs-AI harness numbers (docs/technical-design.md, "Rule tiers").

## The chance that a turn of a random position ends in a skip rather than a
## placement, so rules that read skip counts see some.
const SKIP_CHANCE: float = 0.05
## The target strictness band from the game design document: a rule should
## forbid roughly 20-60% of placements.
const BAND_LOW: float = 0.2
const BAND_HIGH: float = 0.6


## The share of the position's empty cells the rule forbids its holder, the
## current player, placing the position's colour on; 0 with no empty cell.
static func share_forbidden(rule: Rule, position: MatchPosition) -> float:
	var empty: int = position.board.empty_cells().size()
	if empty == 0:
		return 0.0
	var holder: int = position.current_player()
	var legal: int = RuleChecker.legal_cells(rule, position, holder, position.colour).size()
	return float(empty - legal) / empty


## The rule's strictness over these positions: the average of share_forbidden,
## each position weighing the same; 0 with no position.
static func strictness(rule: Rule, positions: Array[MatchPosition]) -> float:
	if positions.is_empty():
		return 0.0
	var total: float = 0.0
	for position: MatchPosition in positions:
		total += share_forbidden(rule, position)
	return total / positions.size()


## The share of these positions where the rule forbids every empty cell, so
## its holder would skip; 0 with no position.
static func no_legal_cell_share(rule: Rule, positions: Array[MatchPosition]) -> float:
	if positions.is_empty():
		return 0.0
	var dead: int = 0
	for position: MatchPosition in positions:
		if share_forbidden(rule, position) == 1.0:
			dead += 1
	return float(dead) / positions.size()


## Positions random_position makes from one RNG seeded with seed_value.
static func random_positions(count: int, seed_value: int) -> Array[MatchPosition]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var positions: Array[MatchPosition] = []
	for i: int in count:
		positions.append(random_position(rng))
	return positions


## A position a match between two random players could reach, at the start of
## a turn: a coin toss picks the first player, then turns are played until the
## board holds a random number of balls, 0 to 35 (never full). On each turn
## the player skips with SKIP_CHANCE (never a third time) or places a ball of
## a random colour on a random empty cell, so the history holds last balls,
## turn numbers and skips for rules to read. The current player is to place
## a random colour.
static func random_position(rng: RandomNumberGenerator) -> MatchPosition:
	var position: MatchPosition = MatchPosition.new(Board.new(), rng.randi_range(0, Players.COUNT - 1))
	var balls: int = rng.randi_range(0, Board.SIZE * Board.SIZE - 1)
	var placed: int = 0
	_start_turn(position, rng)
	while placed < balls:
		var player: int = position.current_player()
		if position.skips[player] < Match.LOSING_SKIP - 1 and rng.randf() < SKIP_CHANCE:
			position.skips[player] += 1
			position.history.append(HistoryEntry.skip(player, position.colour))
		else:
			var empty: Array[Vector2i] = position.board.empty_cells()
			var cell: Vector2i = empty[rng.randi_range(0, empty.size() - 1)]
			position.board.place(cell, Ball.new(position.colour, player))
			position.history.append(HistoryEntry.placement(player, cell, position.colour))
			placed += 1
		_start_turn(position, rng)
	return position


## The current player picks a random colour for the other player, whose turn
## then starts.
static func _start_turn(position: MatchPosition, rng: RandomNumberGenerator) -> void:
	var colour: String = BallColour.ALL[rng.randi_range(0, BallColour.ALL.size() - 1)]
	position.history.append(HistoryEntry.colour_pick(position.current_player(), colour))
	position.turn += 1
	position.colour = colour


## One row per rule, in the given order: its strictness, its no-legal-cell
## share and where its strictness falls against the target band
## (below, in or above).
static func summary(rules: Array[Rule], positions: Array[MatchPosition]) -> String:
	var lines: Array[String] = ["Rule  Strictness  No legal cell  Band %d-%d%%" % [
		roundi(BAND_LOW * 100.0), roundi(BAND_HIGH * 100.0),
	]]
	for rule: Rule in rules:
		var value: float = strictness(rule, positions)
		lines.append("%-4s  %9.1f%%  %12.1f%%  %s" % [
			rule.id, value * 100.0, no_legal_cell_share(rule, positions) * 100.0, _band(value),
		])
	return "\n".join(lines) + "\n"


static func _band(value: float) -> String:
	if value < BAND_LOW:
		return "below"
	if value > BAND_HIGH:
		return "above"
	return "in"
