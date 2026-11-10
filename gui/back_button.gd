extends Node

## The back button (autoload `BackButton`): Android's back gesture or button
## steps back a screen, as Escape does on desktop. Godot reports it as a
## go-back request, not a key, and would quit the app from any screen
## (`application/config/quit_on_go_back`, off in `project.godot`), so this
## turns the request into a press of `ui_cancel`: every screen's Escape
## handler then serves back too.


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		Input.parse_input_event(cancel_press())


## The press of `ui_cancel` that a go-back request becomes.
static func cancel_press() -> InputEventAction:
	var press: InputEventAction = InputEventAction.new()
	press.action = "ui_cancel"
	press.pressed = true
	return press
