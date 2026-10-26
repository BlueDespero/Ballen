class_name GuessButton
extends Control

## The Guess trigger: press and hold for HOLD_SECONDS while a ring fills, then
## it fires `guessed`. Releasing early cancels and empties the ring. Touch
## works through the mouse events Godot emulates from touches.

## The ring is full: the player pulled the trigger.
signal guessed

const HOLD_SECONDS: float = 1.0
const RING_RADIUS: float = 13.0
const RING_WIDTH: float = 4.0
const FONT_SIZE: int = 20
const FILL_COLOUR: Color = Color(0.62, 0.16, 0.18)
const BORDER_COLOUR: Color = Color(0.93, 0.4, 0.4)
const RING_COLOUR: Color = Color(1.0, 0.86, 0.86)
const TRACK_COLOUR: Color = Color(1.0, 1.0, 1.0, 0.22)

## Whether a hold may start; turning it off cancels a hold in progress.
var enabled: bool = false:
	set(value):
		enabled = value
		if not value:
			_cancel()
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if value else Control.CURSOR_ARROW
		modulate.a = 1.0 if value else 0.35

## How full the ring is, 0 to 1. Read by the run-ballen driver.
var progress: float = 0.0
var _holding: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(150, 48)
	set_process(false)
	enabled = enabled


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if button.pressed and enabled:
		_holding = true
		set_process(true)
		accept_event()
	elif not button.pressed and _holding:
		_cancel()
		accept_event()


func _process(delta: float) -> void:
	progress = minf(progress + delta / HOLD_SECONDS, 1.0)
	queue_redraw()
	if progress >= 1.0:
		_cancel()
		guessed.emit()


func _cancel() -> void:
	_holding = false
	progress = 0.0
	set_process(false)
	queue_redraw()


func _draw() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = FILL_COLOUR.lightened(0.15) if _holding else FILL_COLOUR
	style.set_corner_radius_all(int(size.y / 2.0))
	style.set_border_width_all(2)
	style.border_color = BORDER_COLOUR
	draw_style_box(style, Rect2(Vector2.ZERO, size))
	var centre: Vector2 = Vector2(size.y / 2.0 + 6.0, size.y / 2.0)
	draw_arc(centre, RING_RADIUS, 0.0, TAU, 48, TRACK_COLOUR, RING_WIDTH, true)
	if progress > 0.0:
		draw_arc(centre, RING_RADIUS, -PI / 2.0, -PI / 2.0 + TAU * progress, 48, RING_COLOUR, RING_WIDTH, true)
	var font: Font = get_theme_default_font()
	var text_left: float = centre.x + RING_RADIUS + 12.0
	var baseline: float = (size.y + font.get_ascent(FONT_SIZE) - font.get_descent(FONT_SIZE)) / 2.0
	draw_string(font, Vector2(text_left, baseline), "Guess", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color.WHITE)
