class_name Ball
extends RefCounted

## A ball on the board: one colour, one owner. Treat it as an immutable value.

var colour: String
var owner: int


func _init(p_colour: String, p_owner: int) -> void:
	colour = p_colour
	owner = p_owner


func copy() -> Ball:
	return Ball.new(colour, owner)
