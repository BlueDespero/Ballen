extends Button

## Quit closes the game on desktop. A browser tab can't be closed by the game,
## and quitting there only freezes the canvas, so the button hides on the web.


func _ready() -> void:
	visible = is_shown(OS.has_feature("web"))


static func is_shown(is_web: bool) -> bool:
	return not is_web


func _on_pressed() -> void:
	get_tree().quit()
