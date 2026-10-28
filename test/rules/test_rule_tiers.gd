extends GutTest

# Each rule's tier (Simple, Intermediate or Hardcore) is data in rules.json,
# mirroring the Tier column of docs/rules-library.md.

const LIBRARY_PATH: String = "res://docs/rules-library.md"

var _book: RuleBook


func before_each() -> void:
	_book = RuleBook.load_default()


func test_every_built_rule_has_a_valid_tier() -> void:
	assert_eq(_book.rule_ids().size(), 22)
	for rule_id: String in _book.rule_ids():
		assert_has(Rule.TIERS, _book.rule(rule_id).tier, rule_id)


func test_every_built_rule_s_tier_matches_the_rules_library() -> void:
	var library_tiers: Dictionary[String, String] = _library_tiers()
	for rule_id: String in _book.rule_ids():
		assert_eq(_book.rule(rule_id).tier, library_tiers.get(rule_id, "?"), rule_id)


func test_a_rule_keeps_its_tier_through_its_data() -> void:
	var rule: Rule = _book.rule("R08")
	assert_eq(rule.tier, Rule.TIER_SIMPLE)
	assert_eq(rule.to_data().tier, Rule.TIER_SIMPLE)
	assert_eq(_book.make_rule(rule.to_data()).tier, Rule.TIER_SIMPLE)


func test_rule_data_with_an_unknown_tier_is_rejected() -> void:
	var data: Dictionary = _book.rule("R04").to_data()
	data.tier = "legendary"
	assert_null(_book.make_rule(data))
	assert_push_error("not a tier")


func test_rule_data_without_a_tier_builds_a_rule_with_no_tier() -> void:
	var rule: Rule = _book.make_rule({"id": "X", "text": "?", "template": "not_on_zone", "values": {"zone": "edge"}})
	assert_eq(rule.tier, "")
	assert_false(rule.to_data().has("tier"))


## Tier by rule id from the library table's Built rows, lowercased.
func _library_tiers() -> Dictionary[String, String]:
	var tiers: Dictionary[String, String] = {}
	for line: String in FileAccess.get_file_as_string(LIBRARY_PATH).split("\n"):
		if not line.begins_with("| R"):
			continue
		var cells: PackedStringArray = line.split("|", false)
		if cells.size() < 8 or cells[5].strip_edges() != "Built":
			continue
		tiers[cells[0].strip_edges()] = cells[7].strip_edges().to_lower()
	return tiers
