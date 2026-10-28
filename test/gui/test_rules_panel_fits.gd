extends GutTest

# The rules panel fits the 720 px screen below its top margin in every state,
# at both text sizes, with the longest rules in both decks.

const PANEL_SCENE: PackedScene = preload("res://gui/rules_panel.tscn")
## The panel's place in the match scene.
const PANEL_TOP: float = 16.0
const PANEL_WIDTH: float = 520.0
const SCREEN_HEIGHT: float = 720.0
const LONGEST_RULES: Array[String] = ["R15", "R16", "R17", "R21", "R22"]

var _marks_seen: bool


func before_each() -> void:
	_marks_seen = Settings.note_marks_seen
	# The note marks hint shows until the player first uses a mark.
	Settings.note_marks_seen = false


func after_each() -> void:
	Settings.note_marks_seen = _marks_seen


func test_the_panel_fits_the_screen_in_every_state() -> void:
	for scale: float in [1.0, Settings.LARGER_TEXT_SCALE]:
		for without_holding: bool in [false, true]:
			for state: String in ["guess open", "guess and seal", "seal", "board full", "match over"]:
				var height: float = await _height(scale, without_holding, state)
				assert_lte(PANEL_TOP + height, SCREEN_HEIGHT, "bottom at %d px: %s at text scale %s%s"
					% [PANEL_TOP + height, state, scale, ", without holding" if without_holding else ""])


func test_the_note_marks_hint_gives_way_on_a_full_board() -> void:
	var panel: RulesPanel = PANEL_SCENE.instantiate()
	add_child_autofree(panel)
	var deck: Deck = _longest_deck()
	panel.show_decks(deck, _longest_deck(), deck.rules[0])
	var hint: Control = panel.get_node("%MarkHint")
	assert_true(hint.visible, "shown until the player first uses a mark")
	panel.board_full = true
	assert_false(hint.visible, "hidden on a full board")
	panel.board_full = false
	assert_true(hint.visible, "back once the board is no longer full (a rematch)")


func _height(scale: float, without_holding: bool, state: String) -> float:
	var panel: RulesPanel = PANEL_SCENE.instantiate()
	add_child_autofree(panel)
	panel.size = Vector2(PANEL_WIDTH, 0.0)
	panel.guess_without_holding = without_holding
	panel.text_scale = scale
	var deck: Deck = _longest_deck()
	panel.show_decks(deck, _longest_deck(), deck.rules[2])
	panel.show_skips(1, 1)
	var selected: String = deck.rules[2].id
	match state:
		"guess open":
			panel.guess_enabled = true
		"guess and seal":
			panel.board_full = true
			panel.guess_enabled = true
			panel.seal_enabled = true
		"seal":
			panel.board_full = true
			panel.seal_enabled = true
		"board full":
			panel.board_full = true
		"match over":
			panel.show_match_over(deck.rules[2])
			selected = ""
	if selected != "":
		panel.call("_select", selected)
	# Wrapped labels report their height once laid out at their width.
	await wait_process_frames(3)
	return panel.get_combined_minimum_size().y


func _longest_deck() -> Deck:
	var book: RuleBook = RuleBook.load_default()
	var rules: Array[Rule] = []
	for rule_id: String in LONGEST_RULES:
		rules.append(book.rule(rule_id))
	return Deck.new(rules)
