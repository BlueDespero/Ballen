class_name ColourPicker
extends HBoxContainer

## Four colour buttons beside the player's ball: the colour the AI places
## next. Picking one ends the player's turn. While the pick is due the
## buttons light up and a ring pulses around each; otherwise they are dimmed
## and disabled.

signal picked(colour: String)

const BUTTON_SIZE: Vector2 = Vector2(48, 48)
## Ring around each button, just inside the gap between buttons.
const RING_RADIUS: float = 27.0
const RING_WIDTH_MIN: float = 2.0
const RING_WIDTH_MAX: float = 4.0
const RING_ALPHA_MIN: float = 0.15
## One fade from dim to bright (or back).
const PULSE_SECONDS: float = 0.6
const DIMMED_ALPHA: float = 0.35

## Whether the player may pick now.
var enabled: bool = false:
	set(value):
		enabled = value
		for button: Button in _buttons:
			button.disabled = not value
		modulate.a = 1.0 if value else DIMMED_ALPHA
		_update_pulse()

## Reduced motion: the ring stays still instead of pulsing.
var reduced_motion: bool = false:
	set(value):
		reduced_motion = value
		_update_pulse()

var _buttons: Array[Button] = []
## 0 = ring at its dimmest, 1 = brightest.
var _pulse: float = 1.0:
	set(value):
		_pulse = value
		queue_redraw()
var _pulse_tween: Tween = null


func _ready() -> void:
	for colour: String in BallColour.ALL:
		var button: Button = Button.new()
		button.name = colour.capitalize()
		button.tooltip_text = colour.capitalize()
		button.custom_minimum_size = BUTTON_SIZE
		button.focus_mode = Control.FOCUS_NONE
		var rgb: Color = Constants.colors[colour]["rgb"]
		button.add_theme_stylebox_override("normal", _style(rgb, 0.0))
		button.add_theme_stylebox_override("hover", _style(rgb.lightened(0.25), 3.0))
		button.add_theme_stylebox_override("pressed", _style(rgb.darkened(0.2), 3.0))
		button.add_theme_stylebox_override("disabled", _style(rgb.darkened(0.4), 0.0))
		button.pressed.connect(picked.emit.bind(colour))
		add_child(button)
		_buttons.append(button)
	enabled = enabled


func _draw() -> void:
	if not enabled:
		return
	var colour: Color = Color(BoardView.GLOW_COLOUR, lerpf(RING_ALPHA_MIN, 1.0, _pulse))
	var width: float = lerpf(RING_WIDTH_MIN, RING_WIDTH_MAX, _pulse)
	for button: Button in _buttons:
		var centre: Vector2 = button.position + button.size / 2.0
		draw_arc(centre, RING_RADIUS, 0.0, TAU, 48, colour, width, true)


## Pulses the ring while enabled, unless motion is reduced; a still ring
## shows at full brightness.
func _update_pulse() -> void:
	if _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
	_pulse = 1.0
	if not enabled or reduced_motion or not is_inside_tree():
		return
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(self, "_pulse", 0.0, PULSE_SECONDS)
	_pulse_tween.tween_property(self, "_pulse", 1.0, PULSE_SECONDS)


func _style(rgb: Color, border: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = rgb
	style.set_corner_radius_all(int(BUTTON_SIZE.x / 2.0))
	style.set_border_width_all(int(border))
	style.border_color = Color.WHITE
	return style
