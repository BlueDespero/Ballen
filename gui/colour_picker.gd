class_name ColourPicker
extends HBoxContainer

## Four colour buttons beside the player's ball: the colour the AI places
## next. Picking one ends the player's turn.

signal picked(colour: String)

const BUTTON_SIZE: Vector2 = Vector2(48, 48)

## Whether the player may pick now.
var enabled: bool = false:
	set(value):
		enabled = value
		for button: Button in _buttons:
			button.disabled = not value
		modulate.a = 1.0 if value else 0.35

var _buttons: Array[Button] = []


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
		button.add_theme_stylebox_override("disabled", _style(rgb, 0.0))
		button.pressed.connect(picked.emit.bind(colour))
		add_child(button)
		_buttons.append(button)
	enabled = enabled


func _style(rgb: Color, border: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = rgb
	style.set_corner_radius_all(int(BUTTON_SIZE.x / 2.0))
	style.set_border_width_all(int(border))
	style.border_color = Color.WHITE
	return style
