class_name Deck
extends RefCounted

## The 5 rules a player brings to a match. Both players see each other's whole
## deck; which rule is true is held by the match, never by the deck.

const SIZE: int = 5

var rules: Array[Rule] = []


func _init(p_rules: Array[Rule]) -> void:
	rules = p_rules.duplicate()


## A deck of SIZE distinct rules drawn at random from the book's built-in rules,
## using only rng (seeded draws repeat). Returns null (and reports an error) if
## the book has fewer than SIZE rules.
static func draw(book: RuleBook, rng: RandomNumberGenerator) -> Deck:
	var ids: Array[String] = book.rule_ids()
	if ids.size() < SIZE:
		push_error("Deck.draw: the book has %d rules, a deck needs %d" % [ids.size(), SIZE])
		return null
	var drawn: Array[Rule] = []
	for i: int in SIZE:
		var pick: int = rng.randi_range(i, ids.size() - 1)
		var rule_id: String = ids[pick]
		ids[pick] = ids[i]
		ids[i] = rule_id
		drawn.append(book.rule(rule_id))
	return Deck.new(drawn)


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
