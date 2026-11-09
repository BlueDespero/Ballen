extends GutTest

# The Guess (or Seal) button. By default a tap asks for the stakes card; with
# Hold to guess the player holds it while a ring fills, and letting go early
# says so instead of doing nothing.


func _button(hold: bool) -> GuessButton:
	var button: GuessButton = GuessButton.new()
	add_child_autofree(button)
	button.size = button.custom_minimum_size
	button.enabled = true
	button.hold = hold
	watch_signals(button)
	return button


func _event(pressed: bool) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = Vector2(10, 10)
	return event


func _tap(button: GuessButton) -> void:
	button._gui_input(_event(true))
	button._gui_input(_event(false))


func test_a_tap_asks_for_the_stakes_card() -> void:
	var button: GuessButton = _button(false)
	_tap(button)
	assert_signal_emit_count(button, "pressed_to_guess", 1)
	assert_signal_not_emitted(button, "guessed", "the card confirms, not the tap")


func test_a_tap_that_slides_off_the_button_does_nothing() -> void:
	var button: GuessButton = _button(false)
	button._gui_input(_event(true))
	var release: InputEventMouseButton = _event(false)
	release.position = Vector2(-20, -20)
	button._gui_input(release)
	assert_signal_not_emitted(button, "pressed_to_guess")


func test_holding_to_the_end_guesses() -> void:
	var button: GuessButton = _button(true)
	button._gui_input(_event(true))
	button._process(GuessButton.HOLD_SECONDS / 2.0)
	assert_signal_not_emitted(button, "guessed", "not halfway")
	button._process(GuessButton.HOLD_SECONDS / 2.0)
	assert_signal_emit_count(button, "guessed", 1)
	assert_signal_not_emitted(button, "pressed_to_guess")


func test_letting_go_early_says_so_and_does_not_guess() -> void:
	var button: GuessButton = _button(true)
	_tap(button)
	assert_signal_not_emitted(button, "guessed")
	assert_signal_emit_count(button, "released_early", 1)
	assert_eq(button.progress, 0.0, "the ring empties")


func test_disabling_cancels_a_hold() -> void:
	var button: GuessButton = _button(true)
	button._gui_input(_event(true))
	button._process(GuessButton.HOLD_SECONDS / 2.0)
	button.enabled = false
	assert_eq(button.progress, 0.0)


func test_an_available_button_reports_a_press_as_blocked() -> void:
	var button: GuessButton = _button(false)
	button.enabled = false
	button.available = true
	_tap(button)
	assert_signal_emit_count(button, "blocked", 1)
	assert_signal_not_emitted(button, "pressed_to_guess")


func test_an_available_button_is_outlined_not_dimmed() -> void:
	var button: GuessButton = _button(false)
	button.enabled = false
	assert_almost_eq(button.modulate.a, 0.35, 0.001, "dimmed while guessing is closed")
	button.available = true
	assert_eq(button.modulate.a, 1.0, "full strength while a guess could be made")


func test_an_enabled_button_never_reports_blocked() -> void:
	var button: GuessButton = _button(false)
	button.available = true
	_tap(button)
	assert_signal_not_emitted(button, "blocked")
