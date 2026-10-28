extends Control

const SETTINGS_SCENE: String = "res://gui/menus/settings_menu.tscn"


func _ready() -> void:
	Settings.changed.connect(_apply_text_scale)
	_apply_text_scale()


func _on_single_player_button_pressed() -> void:
	get_tree().change_scene_to_file("res://main_game.tscn")
	queue_free()


func _on_option_button_pressed() -> void:
	get_tree().change_scene_to_file(SETTINGS_SCENE)


## Larger text.
func _apply_text_scale() -> void:
	TextScale.apply(self, Settings.text_scale())
