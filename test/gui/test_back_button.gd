extends GutTest

# Android's back button reaches the game as a go-back request; it must act as
# Escape (ui_cancel) on every screen instead of quitting the app.

const BackButtonScript: GDScript = preload("res://gui/back_button.gd")


class CancelCounter:
	extends Node
	var cancels: int = 0

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_cancel"):
			cancels += 1


func test_back_does_not_quit_the_app_by_itself() -> void:
	assert_false(ProjectSettings.get_setting("application/config/quit_on_go_back"),
		"screens decide what back does; the main menu closes the app itself")


func test_the_press_is_ui_cancel() -> void:
	var press: InputEventAction = BackButtonScript.cancel_press()
	assert_true(press.is_action_pressed("ui_cancel"))


func test_a_go_back_request_reaches_the_screens_as_ui_cancel() -> void:
	var counter: CancelCounter = add_child_autofree(CancelCounter.new())
	var back: Node = add_child_autofree(BackButtonScript.new())
	back.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await wait_process_frames(2)
	assert_eq(counter.cancels, 1)


func test_other_notifications_press_nothing() -> void:
	var counter: CancelCounter = add_child_autofree(CancelCounter.new())
	var back: Node = add_child_autofree(BackButtonScript.new())
	back.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	await wait_process_frames(2)
	assert_eq(counter.cancels, 0)
