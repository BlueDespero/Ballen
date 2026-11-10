class_name SoftmaxColourPick
extends InformationColourPick

## Hard's colour pick: the information-gain values of InformationColourPick,
## but the colour is drawn with chance ∝ e^(precision × value / best value)
## rather than always the best. An AI that always hands over the most
## telling colour tells an attentive player what it suspects; drawing keeps
## that unreadable while still favouring the telling colours strongly.

## How strongly the draw favours the best colours; higher is closer to always
## the best.
var precision: float = 6.0


func _init(model: OpponentModel, p_precision: float = 6.0) -> void:
	super(model)
	precision = p_precision


func choose(view: PublicView, belief: Belief, rng: RandomNumberGenerator) -> String:
	var scores: Dictionary[String, float] = {}
	var best: float = 0.0
	for colour: String in BallColour.ALL:
		scores[colour] = value(view, belief, colour)
		best = maxf(best, scores[colour])
	last_closeness = closeness(scores)
	if best < WORTH_WEIGHING:
		return best_of(scores, rng)
	var weights: Array[float] = []
	var total: float = 0.0
	for colour: String in BallColour.ALL:
		var weight: float = exp(precision * (scores[colour] - best) / best)
		weights.append(weight)
		total += weight
	var draw: float = rng.randf() * total
	for i: int in BallColour.ALL.size():
		draw -= weights[i]
		if draw <= 0.0:
			return BallColour.ALL[i]
	return BallColour.ALL[-1]
