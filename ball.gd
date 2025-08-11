extends CharacterBody2D

var dragging: bool = false

func _process(delta: float) -> void:
	if dragging:
		var mousepos = get_viewport().get_mouse_position()
		self.position = Vector2(mousepos.x, mousepos.y)
		
func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event : InputEventMouseButton = event
		if event.is_pressed():
			dragging = true
		if event.is_released():
			dragging = false
