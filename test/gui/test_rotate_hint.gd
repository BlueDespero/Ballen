extends GutTest

# The rotate hint covers the screen while the visible rect is taller than it
# is wide (a phone held upright); the game plays in landscape.

const RotateHintScript: GDScript = preload("res://gui/rotate_hint.gd")


# Phones and tablets hold the game sideways either way round; the hint is
# left for windows that are still tall (split screen).
func test_the_mobile_apps_lock_to_landscape_both_ways() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/handheld/orientation"),
		DisplayServer.SCREEN_SENSOR_LANDSCAPE)


func test_shows_when_taller_than_wide() -> void:
	assert_true(RotateHint.should_show(Vector2(1280, 2770)))


func test_hidden_when_wider_than_tall() -> void:
	assert_false(RotateHint.should_show(Vector2(1280, 720)))


func test_hidden_on_a_square_screen() -> void:
	assert_false(RotateHint.should_show(Vector2(900, 900)))


func test_the_hint_follows_the_size_it_is_given() -> void:
	var hint: CanvasLayer = add_child_autofree(RotateHintScript.new())
	hint.call("fit", Vector2(1280, 2770))
	assert_true(hint.visible, "upright")
	hint.call("fit", Vector2(1280, 720))
	assert_false(hint.visible, "sideways")
