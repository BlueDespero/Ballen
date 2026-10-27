extends Control

## The Settings screen, opened by the main menu's Options button. Every change
## goes straight into the Settings autoload and is saved at once; Back (or
## Escape) returns to the main menu.

const MAIN_MENU_SCENE: String = "res://main.tscn"

@onready var _volume: HSlider = %Volume
@onready var _volume_value: Label = %VolumeValue


func _ready() -> void:
	_volume.value = roundf(Settings.volume * 100.0)
	_show_volume(_volume.value)
	_volume.value_changed.connect(_on_volume_changed)
	%Back.pressed.connect(_on_back_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _on_volume_changed(percent: float) -> void:
	_show_volume(percent)
	Settings.volume = percent / 100.0
	Settings.save_settings()


func _show_volume(percent: float) -> void:
	_volume_value.text = "%d%%" % int(percent)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
