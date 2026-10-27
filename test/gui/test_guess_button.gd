extends GutTest

# The Guess (or Seal) trigger. By default the player holds it while a ring
# fills; with "guess without holding" a tap arms it and a second tap on
# Confirm pulls the trigger.


func _button(tap_to_confirm: bool) -> GuessButton:
	var button: GuessButton = GuessButton.new()
	add_child_autofree(button)
	button.enabled = true
	button.tap_to_confirm = tap_to_confirm
	watch_signals(button)
	return button


func _tap(button: GuessButton) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		button._gui_input(event)


func test_a_tap_on_the_hold_trigger_does_not_guess() -> void:
	var button: GuessButton = _button(false)
	_tap(button)
	assert_signal_not_emitted(button, "guessed")


func test_without_holding_a_first_tap_asks_for_confirmation() -> void:
	var button: GuessButton = _button(true)
	_tap(button)
	assert_signal_not_emitted(button, "guessed")
	assert_true(button.armed, "the button now waits for Confirm")


func test_without_holding_a_second_tap_confirms_the_guess() -> void:
	var button: GuessButton = _button(true)
	_tap(button)
	_tap(button)
	assert_signal_emit_count(button, "guessed", 1)
	assert_false(button.armed, "back to its first step after the guess")


func test_an_armed_button_disarms_when_guessing_closes() -> void:
	var button: GuessButton = _button(true)
	_tap(button)
	button.enabled = false
	button.enabled = true
	assert_false(button.armed)
	_tap(button)
	assert_signal_not_emitted(button, "guessed", "the next tap only arms it again")


func test_cancel_disarms_the_button() -> void:
	var button: GuessButton = _button(true)
	_tap(button)
	button.cancel()
	assert_false(button.armed)


func test_an_armed_button_gives_up_waiting_for_confirm() -> void:
	var button: GuessButton = _button(true)
	_tap(button)
	button._process(GuessButton.CONFIRM_SECONDS / 2.0)
	assert_true(button.armed, "still waiting halfway")
	button._process(GuessButton.CONFIRM_SECONDS / 2.0)
	assert_false(button.armed)
