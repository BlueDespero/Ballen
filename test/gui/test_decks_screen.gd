extends GutTest

# The Decks screen: a row per deck (Starter first, copy only), renaming and
# deleting through its dialog, and the deck editor opened over it.

const SCREEN_SCENE: PackedScene = preload("res://gui/menus/decks_screen.tscn")
const FIVE: Array[String] = ["R02", "R04", "R06", "R07", "R09"]

var _book: RuleBook
var _path: String


func before_each() -> void:
	_book = RuleBook.load_default()
	# One file per process: other worktrees may run the suite at the same time.
	_path = "user://test_decks_screen_%d.json" % OS.get_process_id()
	DirAccess.remove_absolute(_path)


func after_each() -> void:
	DirAccess.remove_absolute(_path)


func _screen(saved_names: Array[String]) -> DecksScreen:
	var store: DeckStore = DeckStore.new(_book, _path)
	for deck_name: String in saved_names:
		store.save(deck_name, DeckDraft.new(deck_name, FIVE).to_deck(_book))
	var screen: DecksScreen = SCREEN_SCENE.instantiate()
	screen.store_path = _path
	add_child_autofree(screen)
	return screen


func _row(screen: DecksScreen, deck_name: String) -> Node:
	for row: Node in screen.get_node("%DeckList").get_children():
		if row.get_meta(DecksScreen.DECK_NAME_META) == deck_name:
			return row
	return null


func _row_buttons(screen: DecksScreen, deck_name: String) -> Array:
	var buttons: Array = _row(screen, deck_name).find_children("*", "Button", true, false)
	return buttons.map(func(button: Button) -> String: return button.text)


func _press(screen: DecksScreen, deck_name: String, button_text: String) -> void:
	_row(screen, deck_name).find_child(button_text, true, false).pressed.emit()


func _row_names(screen: DecksScreen) -> Array:
	return screen.get_node("%DeckList").get_children().map(func(row: Node) -> String: return row.get_meta(DecksScreen.DECK_NAME_META))


func test_starter_comes_first_and_can_only_be_copied() -> void:
	var screen: DecksScreen = _screen(["Mine"])
	assert_eq(_row_names(screen), ["Starter", "Mine"])
	assert_eq(_row_buttons(screen, "Starter"), ["Copy"])
	assert_eq(_row_buttons(screen, "Mine"), ["Edit", "Rename", "Delete"])


func test_a_row_shows_the_deck_s_rule_ids() -> void:
	var screen: DecksScreen = _screen(["Mine"])
	var labels: Array = _row(screen, "Mine").get_node("Line/Rules").find_children("*", "Label", false, false)
	assert_eq(labels.map(func(label: Label) -> String: return label.text), Array(FIVE))


func test_decks_named_alike_but_for_punctuation_keep_their_own_rows() -> void:
	var screen: DecksScreen = _screen(["a.b", "a_b"])
	assert_eq(_row_names(screen), ["Starter", "a.b", "a_b"])
	_press(screen, "a_b", "Delete")
	screen.get_node("%DialogConfirm").pressed.emit()
	assert_eq(_row_names(screen), ["Starter", "a.b"])


func test_delete_asks_first_and_removes_the_deck_once_confirmed() -> void:
	var screen: DecksScreen = _screen(["One", "Two"])
	_press(screen, "One", "Delete")
	assert_true(screen.get_node("%Dialog").visible)
	assert_eq(_row_names(screen), ["Starter", "One", "Two"], "nothing deleted before the confirm")
	screen.get_node("%DialogConfirm").pressed.emit()
	assert_false(screen.get_node("%Dialog").visible)
	assert_eq(_row_names(screen), ["Starter", "Two"])
	assert_eq(DeckStore.new(_book, _path).names(), ["Starter", "Two"] as Array[String])


func test_a_cancelled_delete_keeps_the_deck() -> void:
	var screen: DecksScreen = _screen(["One"])
	_press(screen, "One", "Delete")
	screen.get_node("%DialogCancel").pressed.emit()
	assert_false(screen.get_node("%Dialog").visible)
	assert_eq(_row_names(screen), ["Starter", "One"])


func test_rename_refuses_a_taken_name_and_renames_to_a_free_one() -> void:
	var screen: DecksScreen = _screen(["One", "Two"])
	_press(screen, "One", "Rename")
	var field: LineEdit = screen.get_node("%DialogName")
	assert_eq(field.text, "One")
	field.text = "Two"
	field.text_changed.emit("Two")
	assert_true(screen.get_node("%DialogConfirm").disabled)
	assert_eq(screen.get_node("%DialogHint").text, "A deck named Two already exists")
	field.text = "Uno"
	field.text_changed.emit("Uno")
	screen.get_node("%DialogConfirm").pressed.emit()
	assert_eq(_row_names(screen), ["Starter", "Uno", "Two"])


func test_copying_starter_opens_the_editor_on_starter_copy() -> void:
	var screen: DecksScreen = _screen([])
	_press(screen, "Starter", "Copy")
	var editor: DeckEditor = screen.find_child("DeckEditor", false, false)
	assert_not_null(editor)
	assert_eq((editor.get_node("%NameField") as LineEdit).text, "Starter copy")
	assert_eq((editor.get_node("%Counter") as Label).text, "5 / 5")
	editor.get_node("%SaveButton").pressed.emit()
	assert_null(screen.find_child("DeckEditor", false, false), "Save returns to the list")
	assert_eq(_row_names(screen), ["Starter", "Starter copy"])
	await wait_process_frames(1) # the closed editor is freed


func test_editing_a_deck_and_cancelling_changes_nothing() -> void:
	var screen: DecksScreen = _screen(["Mine"])
	_press(screen, "Mine", "Edit")
	var editor: DeckEditor = screen.find_child("DeckEditor", false, false)
	assert_eq((editor.get_node("%NameField") as LineEdit).text, "Mine")
	editor.get_node("%CancelButton").pressed.emit()
	assert_null(screen.find_child("DeckEditor", false, false))
	assert_eq(_row_names(screen), ["Starter", "Mine"])
	await wait_process_frames(1) # the closed editor is freed
