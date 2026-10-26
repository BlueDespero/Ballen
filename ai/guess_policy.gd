class_name GuessPolicy
extends RefCounted

## When the AI names the opponent's true rule: as soon as its top candidate's
## confidence reaches the threshold. Swappable: hand AIController another
## threshold, or a subclass with another confidence model (later difficulty
## levels).
##
## Under hard elimination every candidate is equally likely, so confidence is
## 1 / candidates; the default threshold of 1 guesses only when one remains.

var threshold: float


func _init(p_threshold: float = 1.0) -> void:
	threshold = p_threshold


## The candidate's chance of being the opponent's true rule.
func confidence(_candidate: Rule, candidates: Array[Rule]) -> float:
	return 1.0 / candidates.size()


## The candidate to name now, or null to hold off.
func choose(candidates: Array[Rule]) -> Rule:
	var top: Rule = null
	var top_confidence: float = 0.0
	for candidate: Rule in candidates:
		var candidate_confidence: float = confidence(candidate, candidates)
		if candidate_confidence > top_confidence:
			top = candidate
			top_confidence = candidate_confidence
	if top == null or top_confidence < threshold:
		return null
	return top
