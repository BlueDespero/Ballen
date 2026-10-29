extends GutTest

# While the match setup screen is up, the rules panel shows the decks as a
# preview (no true rule chosen yet): the AI's rules take no note marks and no
# selection until the match starts.

const PANEL_SCENE: PackedScene = preload("res://gui/rules_panel.tscn")


func _panel() -> RulesPanel:
	var panel: RulesPanel = PANEL_SCENE.instantiate()
	add_child_autofree(panel)
	return panel


func _deck() -> Deck:
	var book: RuleBook = RuleBook.load_default()
	var rules: Array[Rule] = []
	for rule_id: String in ["R01", "R02", "R03", "R04", "R05"]:
		rules.append(book.rule(rule_id))
	return Deck.new(rules)


func _mark_buttons(panel: RulesPanel) -> Array[NoteMarkButton]:
	var buttons: Array[NoteMarkButton] = []
	for row: Node in panel.get_node("%AIRules").get_children():
		buttons.append(row.get_node("Line/Marks/Cross") as NoteMarkButton)
		buttons.append(row.get_node("Line/Marks/Question") as NoteMarkButton)
	return buttons


func _click(row: Control) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	row.gui_input.emit(event)


func test_the_mark_buttons_are_off_before_the_match() -> void:
	var panel: RulesPanel = _panel()
	panel.show_decks(_deck(), _deck(), null)
	for button: NoteMarkButton in _mark_buttons(panel):
		assert_true(button.disabled, "%s off in the preview" % button.get_path())
		assert_eq(button.mouse_default_cursor_shape, Control.CURSOR_ARROW, "no pointing hand")


func test_a_rule_cannot_be_selected_before_the_match() -> void:
	var panel: RulesPanel = _panel()
	panel.show_decks(_deck(), _deck(), null)
	var row: PanelContainer = panel.get_node("%AIRules").get_child(0)
	_click(row)
	assert_eq(panel.selected_rule_id, "", "the preview takes no selection")
	assert_eq(row.mouse_default_cursor_shape, Control.CURSOR_ARROW, "no pointing hand")


func test_marks_and_selection_work_once_the_match_starts() -> void:
	var panel: RulesPanel = _panel()
	var deck: Deck = _deck()
	panel.show_decks(_deck(), deck, null)
	panel.show_decks(_deck(), deck, deck.rules[0])
	for button: NoteMarkButton in _mark_buttons(panel):
		assert_false(button.disabled, "%s on in the match" % button.get_path())
	var row: PanelContainer = panel.get_node("%AIRules").get_child(0)
	_click(row)
	assert_eq(panel.selected_rule_id, String(row.name), "the match takes a selection")
