class_name HistoryNav
extends HBoxContainer

## The history view's buttons under the board: back a turn, back to the live
## board, forward a turn. It only reports presses; the scene decides which past
## board to show. While the match has moved on behind a past board, Live lights
## up and pulses.

signal back_pressed
signal live_pressed
signal forward_pressed

const BUTTON_HEIGHT: float = 36.0
const ARROW_WIDTH: float = 36.0
const LIVE_WIDTH: float = 52.0
## One fade of the lit Live button from bright to dim (or back).
const PULSE_SECONDS: float = 0.6
const PULSE_DIM_ALPHA: float = 0.45
const LIT_BORDER_WIDTH: int = 2
const LIT_STYLES: Array[String] = ["normal", "hover", "pressed"]
const LIT_FONT_COLOURS: Array[String] = ["font_color", "font_hover_color", "font_pressed_color"]

## Whether Live is lit: a past board is on show and the match has moved on.
var live_lit: bool:
	get:
		return _live_pulse != null

var _back: Button
var _live: Button
var _forward: Button
var _live_pulse: Tween = null


func _ready() -> void:
	_back = _button("Back", "◀", ARROW_WIDTH, "Previous turn (←)", back_pressed)
	_live = _button("Live", "Live", LIVE_WIDTH, "Back to the live board", live_pressed)
	_forward = _button("Forward", "▶", ARROW_WIDTH, "Next turn (→)", forward_pressed)
	set_state(false, false)


## Back works while there is an earlier turn to show; Live and forward only
## while a past board is on show. Live lights up while the match has moved on
## since.
func set_state(can_go_back: bool, viewing_past: bool, moved_on: bool = false) -> void:
	_back.disabled = not can_go_back
	_live.disabled = not viewing_past
	_forward.disabled = not viewing_past
	_light_live(viewing_past and moved_on)


## The lit Live button wears the board's glow colour and pulses.
func _light_live(lit: bool) -> void:
	if lit == live_lit:
		return
	if _live_pulse != null:
		_live_pulse.kill()
		_live_pulse = null
	_live.self_modulate = Color.WHITE
	if not lit:
		for state: String in LIT_STYLES:
			_live.remove_theme_stylebox_override(state)
		for font_colour: String in LIT_FONT_COLOURS:
			_live.remove_theme_color_override(font_colour)
		return
	for state: String in LIT_STYLES:
		var style: StyleBoxFlat = (_live.get_theme_stylebox(state) as StyleBoxFlat).duplicate() as StyleBoxFlat
		style.border_color = BoardView.GLOW_COLOUR
		style.set_border_width_all(LIT_BORDER_WIDTH)
		_live.add_theme_stylebox_override(state, style)
	for font_colour: String in LIT_FONT_COLOURS:
		_live.add_theme_color_override(font_colour, BoardView.GLOW_COLOUR)
	_live_pulse = create_tween().set_loops()
	_live_pulse.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_live_pulse.tween_property(_live, "self_modulate:a", PULSE_DIM_ALPHA, PULSE_SECONDS)
	_live_pulse.tween_property(_live, "self_modulate:a", 1.0, PULSE_SECONDS)


func _button(node_name: String, text: String, width: float, tooltip: String, pressed_signal: Signal) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.text = text
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(width, BUTTON_HEIGHT)
	# Arrow keys step through history; a focused button would take them for focus moves.
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(pressed_signal.emit)
	add_child(button)
	return button
