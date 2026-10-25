extends Node

var player_turn : bool = true

func is_player_turn() -> bool:
	return player_turn
	
func change_player() -> void:
	player_turn = not player_turn
