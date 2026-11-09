class_name GuessButton
extends Control

## The Guess button (or Seal, for a forced guess). By default a tap fires
## `pressed_to_guess`, and the rules panel asks for confirmation on a card that
## states the stakes. With `hold` (the "Hold to guess" setting) it is a trigger
## instead: press and hold for HOLD_SECONDS while a ring fills, then it fires
## `guessed`; releasing early cancels, empties the ring and reports
## `released_early`, so the panel can say to keep holding. Touch works through
## the mouse events Godot emulates from touches.
##
## While a guess could be made but no rule is chosen yet, the button is
## `available`: outlined rather than filled, so it reads as the second option
## beside placing, and a press reports `blocked` instead of starting.

## A tap: the player wants to guess and should confirm on the stakes card.
signal pressed_to_guess
## The ring is full: the player held the trigger to the end (hold only).
signal guessed
## The button was pressed while available but not enabled.
signal blocked
## A hold ended before the ring was full (hold only).
signal released_early

const HOLD_SECONDS: float = 1.0
const RING_RADIUS: float = 13.0
const RING_WIDTH: float = 4.0
const FONT_SIZE: int = 20
const FILL_COLOUR: Color = Color(0.62, 0.16, 0.18)
const BORDER_COLOUR: Color = Color(0.93, 0.4, 0.4)
const RING_COLOUR: Color = Color(1.0, 0.86, 0.86)
const TRACK_COLOUR: Color = Color(1.0, 1.0, 1.0, 0.22)

## The word on the button.
@export var label: String = "Guess"

## Whether the button works now; turning it off cancels a hold in progress.
var enabled: bool = false:
	set(value):
		enabled = value
		if not value:
			cancel()
		_update_look()

## Whether a guess could be made once a rule is chosen: outlined, not dimmed.
var available: bool = false:
	set(value):
		available = value
		_update_look()

## Hold while the ring fills instead of tapping.
var hold: bool = false:
	set(value):
		hold = value
		cancel()

## How full the ring is, 0 to 1 (hold only). Read by the run-ballen driver.
var progress: float = 0.0
## A press is down on the button: held (hold) or about to tap.
var _pressing: bool = false


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(150, 48)
	set_process(false)
	enabled = enabled


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if button.pressed and available and not enabled:
		blocked.emit()
		accept_event()
		return
	if button.pressed and enabled:
		_pressing = true
		set_process(hold)
		queue_redraw()
		accept_event()
	elif not button.pressed and _pressing:
		var tapped: bool = not hold and Rect2(Vector2.ZERO, size).has_point(button.position)
		var early: bool = hold
		cancel()
		if tapped:
			pressed_to_guess.emit()
		elif early:
			released_early.emit()
		accept_event()


## No press or hold in progress.
func cancel() -> void:
	_pressing = false
	progress = 0.0
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	progress = minf(progress + delta / HOLD_SECONDS, 1.0)
	queue_redraw()
	if progress >= 1.0:
		cancel()
		guessed.emit()


## Filled and bright while enabled; outlined while only available; outlined
## and dimmed otherwise.
func _update_look() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled or available else Control.CURSOR_ARROW
	modulate.a = 1.0 if enabled or available else 0.35
	queue_redraw()


func _draw() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = FILL_COLOUR.lightened(0.15) if _pressing else FILL_COLOUR
	style.draw_center = enabled
	style.set_corner_radius_all(int(size.y / 2.0))
	style.set_border_width_all(2)
	style.border_color = BORDER_COLOUR
	draw_style_box(style, Rect2(Vector2.ZERO, size))
	var font: Font = get_theme_default_font()
	var text: String = atr(label)
	var text_colour: Color = Color.WHITE if enabled else BORDER_COLOUR
	var baseline: float = (size.y + font.get_ascent(FONT_SIZE) - font.get_descent(FONT_SIZE)) / 2.0
	if not hold:
		draw_string(font, Vector2(0.0, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, FONT_SIZE, text_colour)
		return
	# The trigger's ring, filling while held.
	var centre: Vector2 = Vector2(size.y / 2.0 + 6.0, size.y / 2.0)
	draw_arc(centre, RING_RADIUS, 0.0, TAU, 48, TRACK_COLOUR, RING_WIDTH, true)
	if progress > 0.0:
		draw_arc(centre, RING_RADIUS, -PI / 2.0, -PI / 2.0 + TAU * progress, 48, RING_COLOUR, RING_WIDTH, true)
	var text_left: float = centre.x + RING_RADIUS + 12.0
	draw_string(font, Vector2(text_left, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, text_colour)
