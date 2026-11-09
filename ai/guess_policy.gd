class_name GuessPolicy
extends RefCounted

## When the AI names the opponent's secret rule: as soon as its Belief's most
## likely rule reaches the threshold. This base policy has a fixed threshold:
## the default of 1 guesses only when one rule is left, INF never guesses.
## Subclasses move the threshold with the situation (DangerGuessPolicy).

## Probabilities this close below the threshold still reach it.
const TOLERANCE: float = 1e-9

var _threshold: float


func _init(p_threshold: float = 1.0) -> void:
	_threshold = p_threshold


## How likely the top rule must be for the AI to name it now. exposure is the
## AI's belief about its own rules as the opponent could hold it.
func threshold(_view: PublicView, _exposure: Belief) -> float:
	return _threshold


## The rule to name now, or null to hold off. Only a rule the hard evidence
## left can be named: a ruled-out rule has probability 0.
func choose(belief: Belief, exposure: Belief, view: PublicView, rng: RandomNumberGenerator) -> Rule:
	var top: Rule = belief.top(rng)
	if top == null or belief.probability(top.id) <= 0.0:
		return null
	if belief.probability(top.id) < threshold(view, exposure) - TOLERANCE:
		return null
	return top
