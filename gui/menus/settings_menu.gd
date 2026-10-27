extends Control

## The Settings screen, opened by the main menu's Options button. Every change
## goes straight into the Settings autoload and is saved at once; Back (or
## Escape) returns to the main menu.

const MAIN_MENU_SCENE: String = "res://main.tscn"
const PREVIEW_BALL_SIZE: float = 40.0
const PREVIEW_GAP: float = 12.0

@onready var _volume: HSlider = %Volume
@onready var _volume_value: Label = %VolumeValue
@onready var _symbol_preview: Control = %SymbolPreview


func _ready() -> void:
	_volume.value = roundf(Settings.volume * 100.0)
	_show_volume(_volume.value)
	_volume.value_changed.connect(_on_volume_changed)
	_bind(%ColourBlindSymbols, "colour_blind_symbols")
	_bind(%ReducedMotion, "reduced_motion")
	_bind(%GuessWithoutHolding, "guess_without_holding")
	_bind(%LargerText, "larger_text")
	_symbol_preview.custom_minimum_size = Vector2(
		(PREVIEW_BALL_SIZE + PREVIEW_GAP) * BallColour.ALL.size() - PREVIEW_GAP, PREVIEW_BALL_SIZE)
	_symbol_preview.draw.connect(_draw_symbol_preview)
	Settings.changed.connect(_symbol_preview.queue_redraw)
	Settings.changed.connect(_apply_text_scale)
	_apply_text_scale()
	%Back.pressed.connect(_on_back_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


## A switch for one on/off setting (a property of the Settings autoload).
func _bind(check: CheckButton, setting: String) -> void:
	check.button_pressed = Settings.get(setting)
	check.toggled.connect(_on_toggled.bind(setting))


func _on_toggled(on: bool, setting: String) -> void:
	Settings.set(setting, on)
	Settings.save_settings()


func _on_volume_changed(percent: float) -> void:
	_show_volume(percent)
	Settings.volume = percent / 100.0
	Settings.save_settings()


func _show_volume(percent: float) -> void:
	_volume_value.text = "%d%%" % int(percent)


## The four ball colours as they look on the board now.
func _draw_symbol_preview() -> void:
	for i: int in BallColour.ALL.size():
		var rect: Rect2 = Rect2(Vector2(i * (PREVIEW_BALL_SIZE + PREVIEW_GAP), 0.0), Vector2.ONE * PREVIEW_BALL_SIZE)
		BoardView.draw_ball(_symbol_preview, rect, BallColour.ALL[i], false, Settings.colour_blind_symbols)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


## Larger text applies to this screen as soon as it is switched.
func _apply_text_scale() -> void:
	TextScale.apply(self, Settings.text_scale())
