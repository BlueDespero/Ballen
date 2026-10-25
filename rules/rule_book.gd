class_name RuleBook
extends RefCounted

## Loads templates and rules from data and builds Rule objects (ADR 0001).
##
## Template data: {"blanks": {"<blank>": [allowed values]}, "tree": <part node>}.
## In the tree, a string "$<blank>" is replaced by the rule's value for that blank.
## Rule data: {"id": "R04", "text": "...", "template": "<template id>", "values": {"<blank>": value}}.

const TEMPLATES_PATH: String = "res://rules/data/templates.json"
const RULES_PATH: String = "res://rules/data/rules.json"

const _BLANK_PREFIX: String = "$"

var _templates: Dictionary[String, Dictionary] = {}
var _rules: Dictionary[String, Rule] = {}


## The built-in templates and rules from rules/data/.
static func load_default() -> RuleBook:
	var book: RuleBook = RuleBook.new()
	var templates: Dictionary = _read_json(TEMPLATES_PATH)
	for template_id: String in templates:
		book.add_template(template_id, templates[template_id])
	var rules: Array = _read_json(RULES_PATH)
	for data: Dictionary in rules:
		var rule: Rule = book.make_rule(data)
		if rule != null:
			book._rules[rule.id] = rule
	return book


## Adds a template, e.g. a permissive one defined by a test.
func add_template(template_id: String, data: Dictionary) -> void:
	_templates[template_id] = data.duplicate(true)


## Builds a rule from data without adding it to the book's built-in rules.
## Returns null (and reports an error) when the data doesn't fit its template.
func make_rule(data: Dictionary) -> Rule:
	var template_id: String = data.get("template", "")
	if not _templates.has(template_id):
		push_error("Rule %s: unknown template '%s'" % [data.get("id", "?"), template_id])
		return null
	var template: Dictionary = _templates[template_id]
	var blanks: Dictionary = template.get("blanks", {})
	var values: Dictionary = data.get("values", {})
	for blank: String in blanks:
		if not values.has(blank):
			push_error("Rule %s: no value for blank '%s'" % [data.get("id", "?"), blank])
			return null
		var allowed: Array = blanks[blank]
		if not allowed.is_empty() and not allowed.has(values[blank]):
			push_error("Rule %s: '%s' is not allowed in blank '%s'" % [data.get("id", "?"), values[blank], blank])
			return null
	for value_name: String in values:
		if not blanks.has(value_name):
			push_error("Rule %s: template '%s' has no blank '%s'" % [data.get("id", "?"), template_id, value_name])
			return null
	var tree: Variant = _fill_blanks(template.tree, values)
	if not _parts_exist(tree):
		push_error("Rule %s: template '%s' uses an unknown part" % [data.get("id", "?"), template_id])
		return null
	return Rule.new(data.get("id", ""), data.get("text", ""), template_id, values, tree)


## A built-in rule by id, e.g. "R04"; null if there is none.
func rule(rule_id: String) -> Rule:
	return _rules.get(rule_id)


## The ids of the built-in rules, in data order.
func rule_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(_rules.keys())
	return ids


static func _fill_blanks(node: Variant, values: Dictionary) -> Variant:
	if node is Dictionary:
		var filled: Dictionary = {}
		for key: Variant in node:
			filled[key] = _fill_blanks(node[key], values)
		return filled
	if node is Array:
		var filled_list: Array = []
		for item: Variant in node:
			filled_list.append(_fill_blanks(item, values))
		return filled_list
	if node is String and node.begins_with(_BLANK_PREFIX):
		return values[node.substr(_BLANK_PREFIX.length())]
	return node


static func _parts_exist(node: Variant) -> bool:
	if node is Dictionary:
		if node.has("part") and not Parts.has_part(node.part):
			return false
		for key: Variant in node:
			if not _parts_exist(node[key]):
				return false
	elif node is Array:
		for item: Variant in node:
			if not _parts_exist(item):
				return false
	return true


static func _read_json(path: String) -> Variant:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null:
		push_error("RuleBook: could not read %s" % path)
	return parsed
