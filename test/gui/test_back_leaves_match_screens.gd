extends GutTest

# Back (Escape, or Android's back button) on the match setup and match-end
# screens does what their Main menu button does. During the coin toss the match
# has begun, so the setup screen leaves back to the match.

const SETUP_SCENE: PackedScene = preload("res://gui/match_setup_screen.tscn")
const END_SCENE: PackedScene = preload("res://gui/match_end_overlay.tscn")


func _back() -> InputEventAction:
	var press: InputEventAction = InputEventAction.new()
	press.action = "ui_cancel"
	press.pressed = true
	return press


func test_back_on_the_setup_screen_asks_for_the_main_menu() -> void:
	var setup: MatchSetupScreen = add_child_autofree(SETUP_SCENE.instantiate())
	setup.visible = true
	watch_signals(setup)
	setup._unhandled_input(_back())
	assert_signal_emitted(setup, "main_menu_requested")


func test_back_during_the_coin_toss_is_left_to_the_match() -> void:
	var setup: MatchSetupScreen = add_child_autofree(SETUP_SCENE.instantiate())
	setup.show_coin_toss(true)
	watch_signals(setup)
	setup._unhandled_input(_back())
	assert_signal_not_emitted(setup, "main_menu_requested")


func test_a_hidden_setup_screen_ignores_back() -> void:
	var setup: MatchSetupScreen = add_child_autofree(SETUP_SCENE.instantiate())
	setup.visible = false
	watch_signals(setup)
	setup._unhandled_input(_back())
	assert_signal_not_emitted(setup, "main_menu_requested")


func test_back_on_the_match_end_screen_asks_for_the_main_menu() -> void:
	var end: MatchEndOverlay = add_child_autofree(END_SCENE.instantiate())
	end.visible = true
	watch_signals(end)
	end._unhandled_input(_back())
	assert_signal_emitted(end, "main_menu_requested")


func test_a_hidden_match_end_screen_ignores_back() -> void:
	var end: MatchEndOverlay = add_child_autofree(END_SCENE.instantiate())
	watch_signals(end)
	end._unhandled_input(_back())
	assert_signal_not_emitted(end, "main_menu_requested")
