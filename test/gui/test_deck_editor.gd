extends GutTest

# The deck editor screen: rule rows to pick, the counter, the hint, Save and
# the tier filter chips. The picking rules themselves are DeckDraft's.

const EDITOR_SCENE: PackedScene = preload("res://gui/menus/deck_editor.tscn")
const FIVE: Array[String] = ["R02", "R04", "R06", "R07", "R09"]

var _book: RuleBook
var _path: String
var _store: DeckStore


func before_each() -> void:
	_book = RuleBook.load_default()
	# One file per process: other worktrees may run the suite at the same time.
	_path = "user://test_deck_editor_%d.json" % OS.get_process_id()
	DirAccess.remove_absolute(_path)
	_store = DeckStore.new(_book, _path)


func after_each() -> void:
	DirAccess.remove_absolute(_path)


func _editor(draft: DeckDraft) -> DeckEditor:
	var editor: DeckEditor = EDITOR_SCENE.instantiate()
	add_child_autofree(editor)
	editor.open(draft, _store, _book, "New deck")
	watch_signals(editor)
	return editor


func _click(editor: DeckEditor, rule_id: String) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	editor.get_node("%RuleList").get_node(rule_id).gui_input.emit(event)


func _save_button(editor: DeckEditor) -> Button:
	return editor.get_node("%SaveButton")


func test_every_built_rule_is_a_row_with_its_tier() -> void:
	var editor: DeckEditor = _editor(DeckDraft.new())
	var rows: Array[Node] = editor.get_node("%RuleList").get_children()
	assert_eq(rows.map(func(row: Node) -> String: return row.name), Array(_book.rule_ids()))
	var tier_badge: Node = rows[0].find_child("Tier", true, false)
	assert_eq((tier_badge.get_child(0) as Label).text, "Hardcore", "R01 is Hardcore")


func test_clicking_rows_picks_them_and_counts_them() -> void:
	var editor: DeckEditor = _editor(DeckDraft.new("Mine"))
	_click(editor, "R02")
	_click(editor, "R04")
	assert_eq(editor.get_node("%Counter").text, "2 / 5")
	assert_eq(editor.get_node("%Hint").text, "Pick 5 rules (2 picked)")
	assert_true(_save_button(editor).disabled)


func test_five_picks_and_a_name_enable_save_which_saves_and_closes() -> void:
	var editor: DeckEditor = _editor(DeckDraft.new("Mine"))
	for rule_id: String in FIVE:
		_click(editor, rule_id)
	assert_eq(editor.get_node("%Hint").text, "")
	assert_false(_save_button(editor).disabled)
	_save_button(editor).pressed.emit()
	assert_signal_emitted_with_parameters(editor, "closed", [true])
	assert_eq(_store.names(), ["Starter", "Mine"] as Array[String])


func test_enter_in_the_name_field_saves_only_while_save_is_enabled() -> void:
	var editor: DeckEditor = _editor(DeckDraft.new("Mine", ["R02"] as Array[String]))
	var field: LineEdit = editor.get_node("%NameField")
	field.text_submitted.emit(field.text)
	assert_signal_not_emitted(editor, "closed", "Save is disabled with one rule picked")
	assert_eq(_store.names(), ["Starter"] as Array[String])
	for rule_id: String in ["R04", "R06", "R07", "R09"]:
		_click(editor, rule_id)
	field.text_submitted.emit(field.text)
	assert_signal_emitted_with_parameters(editor, "closed", [true])
	assert_eq(_store.names(), ["Starter", "Mine"] as Array[String])


func test_a_sixth_pick_is_ignored() -> void:
	var editor: DeckEditor = _editor(DeckDraft.new("Mine"))
	for rule_id: String in FIVE + (["R10"] as Array[String]):
		_click(editor, rule_id)
	assert_eq(editor.get_node("%Counter").text, "5 / 5")


func test_typing_a_taken_name_shows_the_problem() -> void:
	var editor: DeckEditor = _editor(DeckDraft.new("", FIVE))
	var field: LineEdit = editor.get_node("%NameField")
	field.text = "Starter"
	field.text_changed.emit("Starter")
	assert_eq(editor.get_node("%Hint").text, "A deck named Starter already exists")
	assert_true(_save_button(editor).disabled)


func test_a_tier_chip_shows_only_that_tier_s_rules() -> void:
	var editor: DeckEditor = _editor(DeckDraft.new())
	editor.get_node("%Chips/Simple").pressed.emit()
	for row: Control in editor.get_node("%RuleList").get_children():
		assert_eq(row.visible, _book.rule(row.name).tier == Rule.TIER_SIMPLE, row.name)
	editor.get_node("%Chips/All").pressed.emit()
	for row: Control in editor.get_node("%RuleList").get_children():
		assert_true(row.visible, row.name)


func test_cancel_closes_without_saving() -> void:
	var editor: DeckEditor = _editor(DeckDraft.new("Mine", FIVE))
	editor.get_node("%CancelButton").pressed.emit()
	assert_signal_emitted_with_parameters(editor, "closed", [false])
	assert_eq(_store.names(), ["Starter"] as Array[String])
