class_name Deck
extends RefCounted

## The 5 rules a player brings to a match. Both players see each other's whole
## deck; which rule is true is held by the match, never by the deck.

const SIZE: int = 5

var rules: Array[Rule] = []


func _init(p_rules: Array[Rule]) -> void:
	rules = p_rules.duplicate()


func has(rule: Rule) -> bool:
	return rules.has(rule)


## Whether a rule with this id is in the deck.
func has_id(rule_id: String) -> bool:
	for rule: Rule in rules:
		if rule.id == rule_id:
			return true
	return false


## A copy of the deck; rules are immutable values, so they are shared.
func copy() -> Deck:
	return Deck.new(rules)
