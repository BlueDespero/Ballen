extends GutTest

# A tap on Guess (or Seal) opens a card over the AI's rules that states the
# stakes and what the player's own notes say; only its Guess button guesses,
# and its safe button sits where Guess was.

const Fixtures := preload("res://test/helpers/fixtures.gd")
const PANEL_SCENE: PackedScene = preload("res://gui/rules_panel.tscn")
const PANEL_WIDTH: float = 520.0
const LONGEST_RULES: Array[String] = ["R15", "R16", "R17", "R21", "R22"]

var _book: RuleBook
var _panel: RulesPanel
var _marks_seen: bool


func before_each() -> void:
	_marks_seen = Settings.note_marks_seen
	# Already seen, so a mark never saves the player's settings file.
	Settings.note_marks_seen = true
	_book = Fixtures.book()
	_panel = PANEL_SCENE.instantiate()
	add_child_autofree(_panel)
	_panel.size = Vector2(PANEL_WIDTH, 0.0)
	var deck: Deck = _deck(["R01", "R03", "R05", "R08", "R18"])
	_panel.show_decks(deck, deck, deck.rules[0])
	_panel.guess_enabled = true
	watch_signals(_panel)


func after_each() -> void:
	Settings.note_marks_seen = _marks_seen


func _deck(ids: Array[String]) -> Deck:
	var rules: Array[Rule] = []
	for rule_id: String in ids:
		rules.append(_book.rule(rule_id))
	return Deck.new(rules)


func _card() -> StakesCard:
	return _panel.find_child("StakesCard", false, false)


func _tap(button: GuessButton) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = Vector2(10, 10)
		button._gui_input(event)


func _tap_guess(rule_id: String) -> void:
	_panel.call("_select", rule_id)
	_tap(_panel.get_node("%GuessButton"))


func test_a_tap_on_guess_opens_the_card_and_does_not_guess() -> void:
	_tap_guess("R03")
	assert_true(_card().visible)
	assert_eq((_card().find_child("Title", true, false) as Label).text, "Guess R03?")
	assert_eq((_card().find_child("Stakes", true, false) as Label).text, "Right: you win. Wrong: you lose.")
	assert_signal_not_emitted(_panel, "guess_requested")


func test_keep_playing_closes_the_card_without_guessing() -> void:
	_tap_guess("R03")
	(_card().find_child("Cancel", true, false) as Button).pressed.emit()
	assert_false(_card().visible)
	assert_signal_not_emitted(_panel, "guess_requested")


func test_the_card_s_guess_button_names_the_rule() -> void:
	_tap_guess("R03")
	(_card().find_child("Confirm", true, false) as Button).pressed.emit()
	assert_signal_emitted_with_parameters(_panel, "guess_requested", ["R03"])


func test_the_safe_button_is_on_the_right_where_guess_was() -> void:
	await wait_process_frames(2)
	_tap_guess("R03")
	await wait_process_frames(2)
	var guess: Button = _card().find_child("Confirm", true, false)
	var keep: Button = _card().find_child("Cancel", true, false)
	assert_eq(keep.text, "Keep playing")
	assert_gt(keep.get_global_rect().position.x, guess.get_global_rect().end.x)
	var guess_button: Control = _panel.get_node("%GuessButton")
	assert_true(keep.get_global_rect().intersects(guess_button.get_global_rect()), "a quick second tap keeps playing")


func test_the_card_counts_the_rules_the_notes_leave() -> void:
	_panel.call("_on_mark_pressed", "R01", NoteMark.Mark.CROSS)
	_panel.call("_on_mark_pressed", "R05", NoteMark.Mark.CROSS)
	_tap_guess("R03")
	assert_eq((_card().find_child("Notes", true, false) as Label).text, "By your notes, 3 of 5 rules are still possible.")


func test_the_card_warns_about_a_rule_the_notes_ruled_out() -> void:
	_panel.call("_on_mark_pressed", "R03", NoteMark.Mark.CROSS)
	_tap_guess("R03")
	assert_eq((_card().find_child("Notes", true, false) as Label).text, "Your notes say you ruled this one out.")


func test_the_card_closes_when_guessing_closes_or_the_pick_changes() -> void:
	_tap_guess("R03")
	_panel.guess_enabled = false
	assert_false(_card().visible, "guessing closed")
	_panel.guess_enabled = true
	_tap_guess("R03")
	_panel.call("_select", "R05")
	assert_false(_card().visible, "another rule picked")


func test_seal_asks_for_the_forced_guess() -> void:
	_panel.board_full = true
	_panel.guess_enabled = false
	_panel.seal_enabled = true
	_panel.call("_select", "R08")
	_tap(_panel.get_node("%SealButton"))
	assert_eq((_card().find_child("Title", true, false) as Label).text, "Seal R08 as your forced guess?")
	(_card().find_child("Confirm", true, false) as Button).pressed.emit()
	assert_signal_emitted_with_parameters(_panel, "seal_requested", ["R08"])


func test_with_hold_to_guess_a_tap_opens_no_card() -> void:
	_panel.hold_to_guess = true
	_tap_guess("R03")
	assert_false(_card().visible)


func test_the_card_fits_over_the_ai_s_rules() -> void:
	var deck: Deck = _deck(LONGEST_RULES)
	for scale: float in [1.0, Settings.LARGER_TEXT_SCALE]:
		_panel.text_scale = scale
		_panel.show_decks(deck, deck, deck.rules[0])
		_panel.guess_enabled = true
		await wait_process_frames(3)
		_tap_guess("R17")
		await wait_process_frames(3)
		assert_lte(_card().get_combined_minimum_size().y, _card().size.y, "text scale %s" % scale)
