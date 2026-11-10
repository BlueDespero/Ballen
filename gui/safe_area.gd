extends Node

## The safe area (autoload `SafeArea`): in the phone and tablet apps, keeps the
## current scene clear of the camera notch or punch hole and rounded corners,
## which landscape puts at the left or right edge. It insets the scene's root
## (every scene's root is a full-screen Control) to the part of the window the
## system calls safe, on every scene change and resize; the strip beside it
## shows the clear colour, the game's dark background. Desktop and web builds
## use the whole window, so it does nothing there.


## The safe part of a window, in the viewport's coordinates: window and safe
## are in screen pixels (the window's rect and the display's safe area), and
## visible_size is the viewport's visible size, which the stretch mode scales
## from the window's. The whole viewport when the two don't overlap.
static func safe_rect(window: Rect2i, safe: Rect2i, visible_size: Vector2) -> Rect2:
	var whole: Rect2 = Rect2(Vector2.ZERO, visible_size)
	var inside: Rect2i = window.intersection(safe)
	if window.size.x <= 0 or window.size.y <= 0 or inside.size.x <= 0 or inside.size.y <= 0:
		return whole
	var factor: Vector2 = visible_size / Vector2(window.size)
	return Rect2(Vector2(inside.position - window.position) * factor, Vector2(inside.size) * factor)


## Fits a full-screen control (anchored to all four edges) to area.
static func fit(control: Control, area: Rect2, visible_size: Vector2) -> void:
	control.offset_left = area.position.x
	control.offset_top = area.position.y
	control.offset_right = area.end.x - visible_size.x
	control.offset_bottom = area.end.y - visible_size.y


func _ready() -> void:
	if OS.has_feature("web") or not OS.has_feature("mobile"):
		return
	get_tree().scene_changed.connect(_apply)
	get_tree().root.size_changed.connect(_apply)
	# The first scene is set after the autoloads are ready.
	await get_tree().process_frame
	_apply()


func _apply() -> void:
	var scene: Control = get_tree().current_scene as Control
	if scene == null:
		return
	var window: Rect2i = Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size())
	var visible_size: Vector2 = get_viewport().get_visible_rect().size
	fit(scene, safe_rect(window, DisplayServer.get_display_safe_area(), visible_size), visible_size)
