extends Control

func _on_single_player_button_pressed() -> void:
	get_tree().change_scene_to_file("res://main_game.tscn")
	queue_free()
