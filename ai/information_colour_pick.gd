class_name InformationColourPick
extends ColourPickStrategy

## Normal's colour pick: the colour whose next opponent turn is expected to
## teach the AI the most, plus a bonus for the chance it forces a skip.
##
## For each colour it looks at the position the opponent will face, the cells
## each of their rules would allow there, and every outcome: a placement on
## some cell, or a skip. With the AI's Belief as the prior and its
## OpponentModel as the likelihood of each outcome (tempered as the belief
## tempers it), the expected information gain is the belief's entropy now less
## its expected entropy after the outcome, in bits. A skip also counts in its
## own right (SKIP_BITS): it costs the opponent a skip pip, and a third skip
## loses them the match.

## The value, in bits, of the opponent skipping, by how many skips they have
## already taken: a third skip ends the match in the AI's favour.
const SKIP_BITS: Array[float] = [0.5, 1.0, 20.0]

## The outcome key for a skip (no cell is ever off the board like this).
const SKIP: Vector2i = Vector2i(-1, -1)

var _model: OpponentModel


func _init(model: OpponentModel) -> void:
	_model = model


func choose(view: PublicView, belief: Belief, rng: RandomNumberGenerator) -> String:
	var scores: Dictionary[String, float] = {}
	for colour: String in BallColour.ALL:
		scores[colour] = value(view, belief, colour)
	last_closeness = closeness(scores)
	return best_of(scores, rng)


## Expected information gain in bits, plus the skip bonus, of handing the
## opponent this colour.
func value(view: PublicView, belief: Belief, colour: String) -> float:
	var opponent: int = view.opponent()
	var next: MatchPosition = next_turn(view, colour)
	var chances: Dictionary[String, float] = belief.probabilities()
	var rules: Array[Rule] = view.decks[opponent].rules
	var legal_by_rule: Dictionary[String, Array] = {}
	for rule: Rule in rules:
		legal_by_rule[rule.id] = RuleChecker.legal_cells(rule, next, opponent, colour)
	var cell_weights: Dictionary[Vector2i, float] = _model.weights(legal_by_rule)
	# P(outcome | rule) for every alive rule; a skip is the outcome SKIP.
	var outcomes: Dictionary[Vector2i, Dictionary] = {}
	var skip_chance: float = 0.0
	for rule: Rule in rules:
		var prior: float = chances[rule.id]
		if prior <= 0.0:
			continue
		var legal: Array = legal_by_rule[rule.id]
		if legal.is_empty():
			_add(outcomes, SKIP, rule.id, 1.0)
			skip_chance += prior
			continue
		for cell: Vector2i in legal:
			_add(outcomes, cell, rule.id, _model.likelihood(cell, legal, cell_weights))
	var expected_after: float = 0.0
	for outcome: Vector2i in outcomes:
		var likelihoods: Dictionary = outcomes[outcome]
		var chance: float = 0.0
		var posterior: Dictionary[String, float] = {}
		var total: float = 0.0
		for rule_id: String in likelihoods:
			chance += chances[rule_id] * likelihoods[rule_id]
			var weight: float = chances[rule_id] * pow(likelihoods[rule_id], _model.temper)
			posterior[rule_id] = weight
			total += weight
		expected_after += chance * _entropy(posterior, total)
	var skips: int = mini(view.position.skips[opponent], SKIP_BITS.size() - 1)
	return belief.entropy() - expected_after + skip_chance * SKIP_BITS[skips]


static func _add(outcomes: Dictionary[Vector2i, Dictionary], outcome: Vector2i, rule_id: String, likelihood: float) -> void:
	if not outcomes.has(outcome):
		outcomes[outcome] = {}
	outcomes[outcome][rule_id] = likelihood


static func _entropy(weights: Dictionary[String, float], total: float) -> float:
	var bits: float = 0.0
	for weight: float in weights.values():
		if weight > 0.0:
			var chance: float = weight / total
			bits -= chance * log(chance) / log(2.0)
	return bits
