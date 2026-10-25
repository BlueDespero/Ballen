class_name Rule
extends RefCounted

## A placement rule: a template plus a value for each blank (ADR 0001).
## Built by RuleBook from JSON-ready data; treat it as an immutable value.

var id: String
## The hand-written player text from the rules library.
var text: String
var template_id: String
var values: Dictionary
# The template tree with every blank filled in.
var _tree: Dictionary


func _init(p_id: String, p_text: String, p_template_id: String, p_values: Dictionary, p_tree: Dictionary) -> void:
	id = p_id
	text = p_text
	template_id = p_template_id
	values = p_values.duplicate(true)
	_tree = p_tree


## Pass / fail for one placement. Pure: no side effects, no scene access.
func passes(ctx: PlacementContext) -> bool:
	return Parts.evaluate(_tree, ctx)


## The rule's data, in the format RuleBook.make_rule reads.
func to_data() -> Dictionary:
	return {"id": id, "text": text, "template": template_id, "values": values.duplicate(true)}
