class_name GuessPolicy
extends RefCounted

## When the AI names the opponent's secret rule: as soon as its Belief's most
## likely rule reaches the threshold. This base policy has a fixed threshold:
## the default of 1 guesses only when one rule is left, INF never guesses.
## Subclasses move the threshold with the situation (DangerGuessPolicy).

## Probabilities this close below the threshold still reach it.
const TOLERANCE: float = 1e-9
## How far from the threshold the top rule must be for the call to be easy.
const CLEAR_MARGIN: float = 0.3

## How close the last call was, 0 (clear either way) to 1 (the top rule right
## at the threshold): the AI's thinking pause grows with it.
var last_closeness: float = 0.0

## For a policy that thinks in steps (RolloutGuessPolicy): stop working at
## about this Time.get_ticks_msec(), 0 for no limit; is_pending() then says
## whether choose() must be called again with the same view to finish.
var deadline_msec: int = 0

var _threshold: float


func _init(p_threshold: float = 1.0) -> void:
	_threshold = p_threshold


## How likely the top rule must be for the AI to name it now. exposure is the
## AI's belief about its own rules as the opponent could hold it.
func threshold(_view: PublicView, _exposure: Belief) -> float:
	return _threshold


## True when the last choose() stopped at its deadline before deciding.
func is_pending() -> bool:
	return false


## The rule to name now, or null to hold off. Only a rule the hard evidence
## left can be named: a ruled-out rule has probability 0.
func choose(belief: Belief, exposure: Belief, view: PublicView, rng: RandomNumberGenerator) -> Rule:
	last_closeness = 0.0
	var top: Rule = belief.top(rng)
	if top == null or belief.probability(top.id) <= 0.0:
		return null
	var chance: float = belief.probability(top.id)
	var bar: float = threshold(view, exposure)
	if is_finite(bar):
		last_closeness = clampf(1.0 - absf(chance - bar) / CLEAR_MARGIN, 0.0, 1.0)
	if chance < bar - TOLERANCE:
		return null
	return top
