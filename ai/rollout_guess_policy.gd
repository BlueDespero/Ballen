class_name RolloutGuessPolicy
extends GuessPolicy

## Hard's guessing with V_wait from playouts (docs/ai-decision-theory-research.md,
## "Guess when confidence beats the value of waiting"). Guessing the top rule
## now is worth 2p − 1 (win +1, loss −1). Waiting is worth the average result
## of `simulations` playouts of the match from here in which the AI doesn't
## guess at this decision (Playouts). It guesses when 2p − 1 ≥ that average.
## p comes from the playouts' tempered belief.

var simulations: int
var _playouts: Playouts


func _init(p_simulations: int = 16, temper: float = 0.1) -> void:
	super(1.0)
	simulations = p_simulations
	_playouts = Playouts.new(temper)


func choose(_belief: Belief, _exposure: Belief, view: PublicView, rng: RandomNumberGenerator) -> Rule:
	last_closeness = 0.0
	_playouts.update(view)
	var belief: Belief = _playouts.belief
	var top: Rule = belief.top(rng)
	if top == null or belief.probability(top.id) <= 0.0:
		return null
	var chance: float = belief.probability(top.id)
	if chance >= 1.0 - TOLERANCE:
		return top
	var waiting: float = value_of_waiting(view, rng)
	last_closeness = clampf(1.0 - absf(2.0 * chance - 1.0 - waiting) / (2.0 * CLEAR_MARGIN), 0.0, 1.0)
	return top if 2.0 * chance - 1.0 >= waiting else null


## The average result for the AI (1 win, −1 loss, 0 draw) of playing on from
## the view without guessing now.
func value_of_waiting(view: PublicView, rng: RandomNumberGenerator) -> float:
	_playouts.update(view)
	if simulations <= 0:
		return 0.0
	var total: float = 0.0
	for i: int in simulations:
		var playout_rng: RandomNumberGenerator = RandomNumberGenerator.new()
		playout_rng.seed = rng.randi()
		total += _playouts.play(view, playout_rng)
	return total / simulations
