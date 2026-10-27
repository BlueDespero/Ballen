extends GutTest

# Saving and loading named decks (each stored as its 5 rule ids) in a JSON file.
# The starter deck is always offered first and can't be changed.

const Fixtures := preload("res://test/helpers/fixtures.gd")

const STARTER: String = DeckStore.STARTER_DECK_NAME
const STARTER_IDS: Array[String] = ["R01", "R03", "R05", "R08", "R18"]
const MIXED_IDS: Array[String] = ["R02", "R04", "R06", "R07", "R09"]

var _book: RuleBook
var _path: String


func before_each() -> void:
	_book = Fixtures.book()
	# One file per process: other worktrees may run the suite at the same time.
	_path = "user://test_deck_store_%d.json" % OS.get_process_id()
	DirAccess.remove_absolute(_path)


func after_each() -> void:
	DirAccess.remove_absolute(_path)


func _ids(deck: Deck) -> Array[String]:
	var ids: Array[String] = []
	for rule: Rule in deck.rules:
		ids.append(rule.id)
	return ids


func _deck(rule_ids: Array[String]) -> Deck:
	var rules: Array[Rule] = []
	for rule_id: String in rule_ids:
		rules.append(_book.rule(rule_id))
	return Deck.new(rules)


## A store holding the given saved decks (written to the file).
func _store_with(deck_names: Array[String]) -> DeckStore:
	var store: DeckStore = DeckStore.new(_book, _path)
	for deck_name: String in deck_names:
		assert_true(store.save(deck_name, _deck(MIXED_IDS)), deck_name)
	return store


func test_with_no_saved_decks_the_store_offers_the_starter_deck() -> void:
	var store: DeckStore = DeckStore.new(_book, _path)
	assert_eq(store.names(), [STARTER] as Array[String])
	assert_eq(_ids(store.deck(STARTER)), STARTER_IDS)


func test_a_saved_deck_loads_from_the_file_in_a_new_store() -> void:
	assert_true(DeckStore.new(_book, _path).save("Mixed", _deck(MIXED_IDS)))
	var store: DeckStore = DeckStore.new(_book, _path)
	assert_eq(store.names(), [STARTER, "Mixed"] as Array[String])
	assert_eq(_ids(store.deck("Mixed")), MIXED_IDS)


func test_the_starter_deck_stays_first_after_decks_are_saved() -> void:
	var store: DeckStore = _store_with(["Zeta", "Alpha"])
	assert_eq(store.names(), [STARTER, "Zeta", "Alpha"] as Array[String])
	assert_eq(_ids(store.deck(STARTER)), STARTER_IDS)


func test_decks_load_in_the_order_they_were_saved_and_a_name_is_replaced_in_place() -> void:
	var store: DeckStore = DeckStore.new(_book, _path)
	store.save("Zeta", _deck(MIXED_IDS))
	store.save("Alpha", _deck(STARTER_IDS))
	store.save("Zeta", _deck(["R10", "R15", "R16", "R19", "R20"]))
	var loaded: DeckStore = DeckStore.new(_book, _path)
	assert_eq(loaded.names(), [STARTER, "Zeta", "Alpha"] as Array[String])
	assert_eq(_ids(loaded.deck("Zeta")), ["R10", "R15", "R16", "R19", "R20"] as Array[String])


func test_only_the_starter_deck_is_read_only() -> void:
	var store: DeckStore = _store_with(["Mine"])
	assert_true(store.is_read_only(STARTER))
	assert_false(store.is_read_only("Mine"))


func test_the_starter_deck_can_t_be_saved_over() -> void:
	var store: DeckStore = DeckStore.new(_book, _path)
	assert_false(store.save(STARTER, _deck(MIXED_IDS)))
	assert_push_error("built-in")
	assert_eq(_ids(store.deck(STARTER)), STARTER_IDS)
	assert_false(FileAccess.file_exists(_path))



func _write_file(text: String) -> void:
	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_a_file_that_isn_t_json_loads_as_no_decks() -> void:
	_write_file("{\"decks\": [{\"name\": ")
	assert_eq(DeckStore.new(_book, _path).names(), [STARTER] as Array[String])
	assert_push_error("could not read")


func test_a_file_of_the_wrong_shape_loads_as_no_decks() -> void:
	for text: String in ["[]", "{}", "{\"decks\": 5}", "{\"decks\": [7]}"]:
		_write_file(text)
		assert_eq(DeckStore.new(_book, _path).names(), [STARTER] as Array[String], text)
	assert_push_error_count(4)


func _file_with(bad_deck: Dictionary) -> String:
	var good_deck: Dictionary = {"name": "Good", "rules": STARTER_IDS}
	return JSON.stringify({"decks": [bad_deck, good_deck]})


func _assert_skipped(bad_deck: Dictionary, error_text: String) -> void:
	_write_file(_file_with(bad_deck))
	var store: DeckStore = DeckStore.new(_book, _path)
	assert_eq(store.names(), [STARTER, "Good"] as Array[String], str(bad_deck))
	assert_push_error(error_text)


func test_a_deck_with_an_unknown_rule_id_is_skipped() -> void:
	_assert_skipped({"name": "Bad", "rules": ["R01", "R03", "R05", "R08", "R99"]}, "unknown rule R99")


func test_a_deck_with_too_few_rules_is_skipped() -> void:
	_assert_skipped({"name": "Bad", "rules": ["R01", "R03", "R05", "R08"]}, "5 rules")


func test_a_deck_with_too_many_rules_is_skipped() -> void:
	_assert_skipped({"name": "Bad", "rules": ["R01", "R03", "R05", "R08", "R18", "R02"]}, "5 rules")


func test_a_deck_with_a_repeated_rule_is_skipped() -> void:
	_assert_skipped({"name": "Bad", "rules": ["R01", "R03", "R05", "R08", "R01"]}, "R01 twice")


func test_a_deck_without_a_name_is_skipped() -> void:
	_assert_skipped({"rules": STARTER_IDS}, "name")
	_assert_skipped({"name": "", "rules": STARTER_IDS}, "name")
	_assert_skipped({"name": 3, "rules": STARTER_IDS}, "name")


func test_a_saved_deck_named_like_the_starter_deck_is_skipped() -> void:
	_write_file(_file_with({"name": STARTER, "rules": MIXED_IDS}))
	var store: DeckStore = DeckStore.new(_book, _path)
	assert_eq(store.names(), [STARTER, "Good"] as Array[String])
	assert_eq(_ids(store.deck(STARTER)), STARTER_IDS)
	assert_push_error("built-in")


func test_a_deck_whose_rules_aren_t_a_list_of_ids_is_skipped() -> void:
	_assert_skipped({"name": "Bad"}, "list of rule ids")
	_assert_skipped({"name": "Bad", "rules": "R01"}, "list of rule ids")
	_assert_skipped({"name": "Bad", "rules": ["R01", "R03", "R05", "R08", 18]}, "list of rule ids")


func test_a_second_deck_with_the_same_name_is_skipped() -> void:
	_write_file(JSON.stringify({"decks": [
		{"name": "Twin", "rules": STARTER_IDS},
		{"name": "Twin", "rules": MIXED_IDS},
	]}))
	var store: DeckStore = DeckStore.new(_book, _path)
	assert_eq(store.names(), [STARTER, "Twin"] as Array[String])
	assert_eq(_ids(store.deck("Twin")), STARTER_IDS)
	assert_push_error("Twin twice")


func test_a_deck_that_wouldn_t_load_is_not_saved() -> void:
	var store: DeckStore = DeckStore.new(_book, _path)
	store.save("Kept", _deck(STARTER_IDS))
	var not_from_the_book: Deck = Fixtures.deck_with(_book, _book.rule("R01"), "X")
	assert_false(store.save("Small", _deck(["R01", "R03", "R05", "R08"])))
	assert_false(store.save("Repeated", _deck(["R01", "R03", "R05", "R08", "R01"])))
	assert_false(store.save("Outside", not_from_the_book))
	assert_false(store.save("", _deck(MIXED_IDS)))
	assert_push_error_count(4)
	assert_eq(store.names(), [STARTER, "Kept"] as Array[String])
	assert_eq(DeckStore.new(_book, _path).names(), [STARTER, "Kept"] as Array[String])


func test_a_deck_that_can_t_be_written_is_not_saved() -> void:
	var store: DeckStore = DeckStore.new(_book, "user://no_such_folder_%d/decks.json" % OS.get_process_id())
	assert_false(store.save("Lost", _deck(STARTER_IDS)))
	assert_push_error("could not write")
	assert_eq(store.names(), [STARTER] as Array[String])


func test_there_is_no_deck_under_an_unknown_name() -> void:
	assert_null(DeckStore.new(_book, _path).deck("Nope"))


func test_a_loaded_deck_holds_the_book_s_rule_objects() -> void:
	DeckStore.new(_book, _path).save("Mixed", _deck(MIXED_IDS))
	for rule: Rule in DeckStore.new(_book, _path).deck("Mixed").rules:
		assert_same(rule, _book.rule(rule.id))
