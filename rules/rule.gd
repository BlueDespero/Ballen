class_name Rule
extends RefCounted

## A placement rule: a template plus a value for each blank (ADR 0001).
## Built by RuleBook from JSON-ready data; treat it as an immutable value.

## How much a rule restricts the player who holds it (docs/rules-library.md).
const TIER_SIMPLE: String = "simple"
const TIER_INTERMEDIATE: String = "intermediate"
const TIER_HARDCORE: String = "hardcore"
const TIERS: Array[String] = [TIER_SIMPLE, TIER_INTERMEDIATE, TIER_HARDCORE]

var id: String
## The hand-written player text from the rules library.
var text: String
var template_id: String
var values: Dictionary
## One of TIERS; "" for a rule without one (e.g. a test rule).
var tier: String
# The template tree with every blank filled in.
var _tree: Dictionary


func _init(p_id: String, p_text: String, p_template_id: String, p_values: Dictionary, p_tree: Dictionary,
		p_tier: String = "") -> void:
	id = p_id
	text = p_text
	template_id = p_template_id
	values = p_values.duplicate(true)
	_tree = p_tree
	tier = p_tier


## Pass / fail for one placement. Pure: no side effects, no scene access.
func passes(ctx: PlacementContext) -> bool:
	return Parts.evaluate(_tree, ctx)


## The rule's data, in the format RuleBook.make_rule reads.
func to_data() -> Dictionary:
	var data: Dictionary = {"id": id, "text": text, "template": template_id, "values": values.duplicate(true)}
	if tier != "":
		data.tier = tier
	return data
