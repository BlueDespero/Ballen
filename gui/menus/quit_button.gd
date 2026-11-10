extends Button

## Quit closes the game on desktop. A browser tab can't be closed by the game,
## and quitting there only freezes the canvas, so the button hides on the web.
## Mobile apps don't quit themselves (Android's back button closes Ballen from
## the main menu), so it hides on phones and tablets too.


func _ready() -> void:
	visible = is_shown(OS.has_feature("web"), OS.has_feature("mobile"))


static func is_shown(is_web: bool, is_mobile: bool) -> bool:
	return not is_web and not is_mobile


func _on_pressed() -> void:
	get_tree().quit()
