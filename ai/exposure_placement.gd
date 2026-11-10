class_name ExposurePlacement
extends PlacementStrategy

## Hard's placement: the cell after which an opponent reading the AI's moves
## (its exposure belief, with the AI's model of a player) would find the AI's
## secret rule least likely. For each legal cell it updates a copy of that
## belief as if the AI had placed there, exactly as the belief updates on a
## real placement, and keeps the cells with the lowest probability for the
## secret rule; among those, the one leaving the most room for its next ball
## (HidingPlacement.room_after); ties at random.
##
## Unlike counting believable rules, this weighs how telling each cell is: a
## cell every rule allows tells nothing, a cell only the secret rule and an
## already doubtful fake allow tells a lot.

## Probabilities closer than this are a tie.
const TIE: float = 1e-6

var _model: OpponentModel


func _init(model: OpponentModel) -> void:
	_model = model


func choose(view: PublicView, exposure: Belief, rng: RandomNumberGenerator) -> Vector2i:
	var cells: Array[Vector2i] = view.own_legal_cells()
	if cells.size() <= 1:
		return pick(cells, rng)
	var chances: Dictionary[String, float] = exposure.probabilities()
	var rules: Array[Rule] = view.decks[view.viewer].rules
	var legal_by_rule: Dictionary[String, Array] = {}
	for rule: Rule in rules:
		legal_by_rule[rule.id] = RuleChecker.legal_cells(rule, view.position, view.viewer, view.position.colour)
	var cell_weights: Dictionary[Vector2i, float] = _model.weights(legal_by_rule)
	var secret: String = view.own_secret_rule.id
	var best: Array[Vector2i] = []
	var lowest: float = INF
	for cell: Vector2i in cells:
		var revealed: float = exposed_after(cell, chances, legal_by_rule, cell_weights, secret)
		if revealed < lowest - TIE:
			best = []
			lowest = revealed
		if revealed < lowest + TIE:
			best.append(cell)
	if best.size() <= 1:
		return pick(best, rng)
	var roomiest: Array[Vector2i] = []
	var most_room: int = -1
	for cell: Vector2i in best:
		var room: int = HidingPlacement.room_after(view, cell)
		if room > most_room:
			roomiest = []
			most_room = room
		if room == most_room:
			roomiest.append(cell)
	return pick(roomiest, rng)


## The probability of the secret rule after a placement on cell, updating
## chances (the exposure now) as the belief would: rules forbidding the cell
## drop out, the rest are weighted by their tempered likelihood.
func exposed_after(cell: Vector2i, chances: Dictionary[String, float], legal_by_rule: Dictionary[String, Array],
		cell_weights: Dictionary[Vector2i, float], secret: String) -> float:
	var total: float = 0.0
	var mine: float = 0.0
	for rule_id: String in legal_by_rule:
		var legal: Array = legal_by_rule[rule_id]
		var prior: float = chances.get(rule_id, 0.0)
		if prior <= 0.0 or not legal.has(cell):
			continue
		var weight: float = prior * pow(_model.likelihood(cell, legal, cell_weights), _model.temper)
		total += weight
		if rule_id == secret:
			mine = weight
	return mine / total if total > 0.0 else 1.0
