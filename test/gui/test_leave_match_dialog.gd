extends GutTest

# Back (Escape, or Android's back button) during a match asks "Leave this
# match?": Leave goes to the main menu, Stay or back again closes the dialog.

const DIALOG_SCENE: PackedScene = preload("res://gui/leave_match_dialog.tscn")
const GAME_SCENE: PackedScene = preload("res://main_game.tscn")


func _back() -> InputEventAction:
	var press: InputEventAction = InputEventAction.new()
	press.action = "ui_cancel"
	press.pressed = true
	return press


func test_the_dialog_starts_closed() -> void:
	var dialog: LeaveMatchDialog = add_child_autofree(DIALOG_SCENE.instantiate())
	assert_false(dialog.visible)


func test_leave_asks_to_leave() -> void:
	var dialog: LeaveMatchDialog = add_child_autofree(DIALOG_SCENE.instantiate())
	dialog.open()
	watch_signals(dialog)
	dialog.get_node("%LeaveButton").pressed.emit()
	assert_signal_emitted(dialog, "leave_confirmed")


func test_stay_closes_the_dialog() -> void:
	var dialog: LeaveMatchDialog = add_child_autofree(DIALOG_SCENE.instantiate())
	dialog.open()
	watch_signals(dialog)
	dialog.get_node("%StayButton").pressed.emit()
	assert_false(dialog.visible)
	assert_signal_not_emitted(dialog, "leave_confirmed")


func test_back_again_closes_the_dialog() -> void:
	var dialog: LeaveMatchDialog = add_child_autofree(DIALOG_SCENE.instantiate())
	dialog.open()
	dialog._unhandled_input(_back())
	assert_false(dialog.visible)


func test_back_during_a_match_opens_the_dialog_and_back_again_closes_it() -> void:
	var game: Control = add_child_autofree(GAME_SCENE.instantiate())
	var dialog: LeaveMatchDialog = game.get_node("%LeaveMatch")
	# Past the setup screen, as after Start.
	game.get_node("%MatchSetup").visible = false
	Input.parse_input_event(_back())
	await wait_process_frames(2)
	assert_true(dialog.visible, "back opens the dialog")
	Input.parse_input_event(_back())
	await wait_process_frames(2)
	assert_false(dialog.visible, "back again closes it")


func test_back_on_the_setup_screen_leaves_the_dialog_closed() -> void:
	var game: Control = add_child_autofree(GAME_SCENE.instantiate())
	var setup: MatchSetupScreen = game.get_node("%MatchSetup")
	setup.main_menu_requested.disconnect(game._on_main_menu_requested)
	watch_signals(setup)
	Input.parse_input_event(_back())
	await wait_process_frames(2)
	assert_signal_emitted(setup, "main_menu_requested", "the setup screen takes back")
	assert_false(game.get_node("%LeaveMatch").visible)
