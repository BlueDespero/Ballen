class_name LeaveMatchDialog
extends ColorRect

## "Leave this match?", over the whole match screen, opened by back (Escape,
## or Android's back button) during a match. Leave asks the scene to go to the
## main menu, recording nothing; Stay, or back again, closes it. It dims and
## blocks everything under it while open.

## The player pressed Leave.
signal leave_confirmed

@onready var _stay_button: Button = %StayButton
@onready var _leave_button: Button = %LeaveButton


func _ready() -> void:
	visible = false
	_stay_button.pressed.connect(close)
	_leave_button.pressed.connect(leave_confirmed.emit)


func open() -> void:
	visible = true


func close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
