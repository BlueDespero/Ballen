class_name GuessButton
extends Control

## A hold-to-pull trigger (Guess, or Seal for a forced guess): press and hold
## for HOLD_SECONDS while a ring fills, then it fires `guessed`. Releasing
## early cancels and empties the ring. Touch works through the mouse events
## Godot emulates from touches.
##
## With tap_to_confirm (the "guess without holding" setting) a tap arms the
## button instead: it reads Confirm with a full ring, and a second tap fires
## `guessed`. Disabling it, cancel() or CONFIRM_SECONDS without a tap disarm it.

## The ring is full: the player pulled the trigger.
signal guessed

const HOLD_SECONDS: float = 1.0
## How long an armed button waits for Confirm.
const CONFIRM_SECONDS: float = 4.0
const CONFIRM_LABEL: String = "Confirm"
const RING_RADIUS: float = 13.0
const RING_WIDTH: float = 4.0
const FONT_SIZE: int = 20
const FILL_COLOUR: Color = Color(0.62, 0.16, 0.18)
const BORDER_COLOUR: Color = Color(0.93, 0.4, 0.4)
const ARMED_BORDER_COLOUR: Color = Color(1.0, 0.86, 0.86)
const RING_COLOUR: Color = Color(1.0, 0.86, 0.86)
const TRACK_COLOUR: Color = Color(1.0, 1.0, 1.0, 0.22)

## The word beside the ring.
@export var label: String = "Guess"

## Whether a hold may start; turning it off cancels a hold in progress.
var enabled: bool = false:
	set(value):
		enabled = value
		if not value:
			cancel()
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if value else Control.CURSOR_ARROW
		modulate.a = 1.0 if value else 0.35

## Tap, then tap Confirm, instead of holding.
var tap_to_confirm: bool = false:
	set(value):
		tap_to_confirm = value
		cancel()

## How full the ring is, 0 to 1. Read by the run-ballen driver.
var progress: float = 0.0
## Whether a first tap is waiting for Confirm (tap_to_confirm only).
var armed: bool = false
var _holding: bool = false
## Seconds the armed button has waited for Confirm.
var _armed_for: float = 0.0


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(150, 48)
	set_process(false)
	enabled = enabled


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if tap_to_confirm:
		if button.pressed and enabled:
			_tap()
			accept_event()
		return
	if button.pressed and enabled:
		_holding = true
		set_process(true)
		accept_event()
	elif not button.pressed and _holding:
		cancel()
		accept_event()


## Back to the first step: no hold in progress, nothing armed.
func cancel() -> void:
	_holding = false
	armed = false
	_armed_for = 0.0
	progress = 0.0
	set_process(false)
	queue_redraw()


## The first tap arms the button, the second (Confirm) fires it.
func _tap() -> void:
	if not armed:
		armed = true
		_armed_for = 0.0
		progress = 1.0
		set_process(true)
		queue_redraw()
		return
	cancel()
	guessed.emit()


func _process(delta: float) -> void:
	if armed:
		_armed_for += delta
		if _armed_for >= CONFIRM_SECONDS:
			cancel()
		return
	progress = minf(progress + delta / HOLD_SECONDS, 1.0)
	queue_redraw()
	if progress >= 1.0:
		cancel()
		guessed.emit()


func _draw() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = FILL_COLOUR.lightened(0.15) if _holding or armed else FILL_COLOUR
	style.set_corner_radius_all(int(size.y / 2.0))
	style.set_border_width_all(3 if armed else 2)
	style.border_color = ARMED_BORDER_COLOUR if armed else BORDER_COLOUR
	draw_style_box(style, Rect2(Vector2.ZERO, size))
	var centre: Vector2 = Vector2(size.y / 2.0 + 6.0, size.y / 2.0)
	draw_arc(centre, RING_RADIUS, 0.0, TAU, 48, TRACK_COLOUR, RING_WIDTH, true)
	if progress > 0.0:
		draw_arc(centre, RING_RADIUS, -PI / 2.0, -PI / 2.0 + TAU * progress, 48, RING_COLOUR, RING_WIDTH, true)
	var font: Font = get_theme_default_font()
	var text_left: float = centre.x + RING_RADIUS + 12.0
	var baseline: float = (size.y + font.get_ascent(FONT_SIZE) - font.get_descent(FONT_SIZE)) / 2.0
	var text: String = CONFIRM_LABEL if armed else label
	draw_string(font, Vector2(text_left, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color.WHITE)
