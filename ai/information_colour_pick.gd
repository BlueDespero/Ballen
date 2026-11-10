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
	var expected_after: float = 0.0
	var skip_chance: float = 0.0
	for outcome: Outcome in outcomes(view, belief, colour):
		expected_after += outcome.chance * _entropy(outcome.posterior)
		if outcome.skip:
			skip_chance = outcome.chance
	var skips: int = mini(view.position.skips[view.opponent()], SKIP_BITS.size() - 1)
	return belief.entropy() - expected_after + skip_chance * SKIP_BITS[skips]


## One way the opponent's next turn in a colour can go: how likely it is, and
## the belief after it.
class Outcome:
	## P(outcome | colour) under the belief now.
	var chance: float
	## The belief after the outcome, by rule id, summing to 1 (tempered as
	## the belief tempers its evidence).
	var posterior: Dictionary[String, float]
	## The opponent skips: no cell for this colour.
	var skip: bool

	func _init(p_chance: float, p_posterior: Dictionary[String, float], p_skip: bool) -> void:
		chance = p_chance
		posterior = p_posterior
		skip = p_skip


## Every outcome of the opponent's next turn in this colour (a placement on
## a cell some live rule allows, or a skip), from the belief now and the
## AI's model of the player.
func outcomes(view: PublicView, belief: Belief, colour: String) -> Array[Outcome]:
	var opponent: int = view.opponent()
	var next: MatchPosition = next_turn(view, colour)
	var chances: Dictionary[String, float] = belief.probabilities()
	var rules: Array[Rule] = view.decks[opponent].rules
	var legal_by_rule: Dictionary[String, Array] = {}
	for rule: Rule in rules:
		legal_by_rule[rule.id] = RuleChecker.legal_cells(rule, next, opponent, colour)
	var cell_weights: Dictionary[Vector2i, float] = _model.weights(legal_by_rule)
	# P(outcome | rule) for every alive rule; a skip is the outcome SKIP.
	var likelihoods_by_outcome: Dictionary[Vector2i, Dictionary] = {}
	for rule: Rule in rules:
		if chances[rule.id] <= 0.0:
			continue
		var legal: Array = legal_by_rule[rule.id]
		if legal.is_empty():
			_add(likelihoods_by_outcome, SKIP, rule.id, 1.0)
			continue
		for cell: Vector2i in legal:
			_add(likelihoods_by_outcome, cell, rule.id, _model.likelihood(cell, legal, cell_weights))
	var found: Array[Outcome] = []
	for outcome: Vector2i in likelihoods_by_outcome:
		var likelihoods: Dictionary = likelihoods_by_outcome[outcome]
		var chance: float = 0.0
		var posterior: Dictionary[String, float] = {}
		var total: float = 0.0
		for rule_id: String in likelihoods:
			chance += chances[rule_id] * likelihoods[rule_id]
			var weight: float = chances[rule_id] * pow(likelihoods[rule_id], _model.temper)
			posterior[rule_id] = weight
			total += weight
		for rule_id: String in posterior:
			posterior[rule_id] /= total
		found.append(Outcome.new(chance, posterior, outcome == SKIP))
	return found


static func _add(outcomes: Dictionary[Vector2i, Dictionary], outcome: Vector2i, rule_id: String, likelihood: float) -> void:
	if not outcomes.has(outcome):
		outcomes[outcome] = {}
	outcomes[outcome][rule_id] = likelihood


static func _entropy(chances: Dictionary[String, float]) -> float:
	var bits: float = 0.0
	for chance: float in chances.values():
		if chance > 0.0:
			bits -= chance * log(chance) / log(2.0)
	return bits
