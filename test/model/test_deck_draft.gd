extends GutTest

# The deck editor's draft: a name and up to 5 picked rules, what stops it from
# being saved, and saving it as a new deck or over the deck it edits.

const FIVE: Array[String] = ["R02", "R04", "R06", "R07", "R09"]

var _book: RuleBook
var _path: String
var _store: DeckStore


func before_each() -> void:
	_book = RuleBook.load_default()
	# One file per process: other worktrees may run the suite at the same time.
	_path = "user://test_deck_draft_%d.json" % OS.get_process_id()
	DirAccess.remove_absolute(_path)
	_store = DeckStore.new(_book, _path)


func after_each() -> void:
	DirAccess.remove_absolute(_path)


func _ids(deck: Deck) -> Array[String]:
	var ids: Array[String] = []
	for rule: Rule in deck.rules:
		ids.append(rule.id)
	return ids


func _picked(deck_name: String, rule_ids: Array[String]) -> DeckDraft:
	var draft: DeckDraft = DeckDraft.new(deck_name)
	for rule_id: String in rule_ids:
		draft.toggle(rule_id)
	return draft


func _save(deck_name: String, rule_ids: Array[String]) -> void:
	assert_true(_picked(deck_name, rule_ids).save_to(_store, _book))


func test_a_new_draft_has_no_rules_and_asks_for_five() -> void:
	var draft: DeckDraft = DeckDraft.new()
	assert_eq(draft.count(), 0)
	assert_eq(draft.problem(_store), "Pick 5 rules (0 picked)")


func test_toggling_a_rule_picks_it_and_toggling_again_drops_it() -> void:
	var draft: DeckDraft = DeckDraft.new("Mine")
	assert_true(draft.toggle("R04"))
	assert_true(draft.toggle("R02"))
	assert_true(draft.has("R04"))
	assert_eq(draft.rule_ids(), ["R04", "R02"] as Array[String])
	assert_eq(draft.problem(_store), "Pick 5 rules (2 picked)")
	assert_true(draft.toggle("R04"))
	assert_false(draft.has("R04"))
	assert_eq(draft.count(), 1)


func test_a_sixth_pick_does_nothing() -> void:
	var draft: DeckDraft = _picked("Mine", FIVE)
	assert_true(draft.is_full())
	assert_false(draft.toggle("R10"))
	assert_false(draft.has("R10"))
	assert_eq(draft.rule_ids(), FIVE)
	assert_true(draft.toggle("R02"), "a picked rule can still be dropped")
	assert_eq(draft.count(), 4)


func test_five_rules_and_a_free_name_have_no_problem() -> void:
	assert_eq(_picked("Mine", FIVE).problem(_store), "")


func test_a_draft_needs_a_name() -> void:
	assert_eq(_picked("", FIVE).problem(_store), "Name the deck")
	assert_eq(_picked("   ", FIVE).problem(_store), "Name the deck")


func test_a_new_draft_can_t_take_another_deck_s_name() -> void:
	_save("Mine", FIVE)
	assert_eq(_picked("Mine", FIVE).problem(_store), "A deck named Mine already exists")
	assert_eq(_picked("Starter", FIVE).problem(_store), "A deck named Starter already exists")


func test_the_rule_count_is_asked_for_before_the_name() -> void:
	assert_eq(_picked("", ["R02"]).problem(_store), "Pick 5 rules (1 picked)")


func test_editing_a_deck_starts_from_its_name_and_rules_and_may_keep_its_name() -> void:
	_save("Mine", FIVE)
	var draft: DeckDraft = DeckDraft.editing(_store, "Mine")
	assert_eq(draft.name, "Mine")
	assert_eq(draft.rule_ids(), FIVE)
	assert_eq(draft.problem(_store), "")


func test_an_edited_deck_can_t_take_another_deck_s_name() -> void:
	_save("Mine", FIVE)
	_save("Other", FIVE)
	var draft: DeckDraft = DeckDraft.editing(_store, "Mine")
	draft.name = "Other"
	assert_eq(draft.problem(_store), "A deck named Other already exists")


func test_a_copy_of_the_starter_deck_is_a_new_draft_named_starter_copy() -> void:
	var draft: DeckDraft = DeckDraft.copy_of(_store, DeckStore.STARTER_DECK_NAME)
	assert_eq(draft.name, "Starter copy")
	assert_eq(draft.rule_ids(), DeckStore.STARTER_DECK_IDS)
	assert_eq(draft.problem(_store), "")
	assert_true(draft.save_to(_store, _book))
	assert_eq(_store.names(), ["Starter", "Starter copy"] as Array[String])


func test_a_copy_takes_the_next_free_copy_name() -> void:
	_save("Starter copy", FIVE)
	_save("Starter copy 2", FIVE)
	assert_eq(DeckDraft.copy_of(_store, "Starter").name, "Starter copy 3")


func test_a_draft_becomes_a_deck_of_the_book_s_rules_in_pick_order() -> void:
	var deck: Deck = _picked("Mine", ["R09", "R02", "R07", "R04", "R06"]).to_deck(_book)
	assert_eq(_ids(deck), ["R09", "R02", "R07", "R04", "R06"] as Array[String])
	assert_same(deck.rules[0], _book.rule("R09"))


func test_saving_a_new_draft_adds_a_deck_under_its_trimmed_name() -> void:
	assert_true(_picked("  Mine ", FIVE).save_to(_store, _book))
	assert_eq(_store.names(), ["Starter", "Mine"] as Array[String])
	assert_eq(_ids(_store.deck("Mine")), FIVE)


func test_saving_an_edited_deck_replaces_it_in_place_even_when_renamed() -> void:
	_save("One", FIVE)
	_save("Two", FIVE)
	var draft: DeckDraft = DeckDraft.editing(_store, "One")
	draft.toggle("R02")
	draft.toggle("R10")
	draft.name = "Uno"
	assert_true(draft.save_to(_store, _book))
	assert_eq(_store.names(), ["Starter", "Uno", "Two"] as Array[String])
	assert_eq(_ids(_store.deck("Uno")), ["R04", "R06", "R07", "R09", "R10"] as Array[String])
	assert_eq(DeckStore.new(_book, _path).names(), ["Starter", "Uno", "Two"] as Array[String])


func test_a_renamed_deck_that_can_t_be_written_keeps_its_old_name_and_rules() -> void:
	_save("One", FIVE)
	var draft: DeckDraft = DeckDraft.editing(_store, "One")
	draft.toggle("R02")
	draft.toggle("R10")
	draft.name = "Uno"
	DirAccess.remove_absolute(_path)
	DirAccess.make_dir_absolute(_path) # a folder where the file should be: writes fail
	assert_false(draft.save_to(_store, _book))
	assert_push_error_count(1)
	assert_eq(_store.names(), ["Starter", "One"] as Array[String])
	assert_eq(_ids(_store.deck("One")), FIVE)
	DirAccess.remove_absolute(_path)


func test_a_draft_with_a_problem_is_not_saved() -> void:
	assert_false(_picked("Mine", ["R02"]).save_to(_store, _book))
	assert_eq(_store.names(), ["Starter"] as Array[String])
