extends GutTest

# The main menu shows the game's version in a corner, so a build can be traced.

const MENU_SCENE: PackedScene = preload("res://gui/menus/main_menu.tscn")


func test_version_label_shows_the_project_version() -> void:
	var menu: Control = MENU_SCENE.instantiate()
	add_child_autofree(menu)
	var version: String = ProjectSettings.get_setting("application/config/version")
	assert_ne(version, "", "project.godot sets a version")
	assert_eq(menu.get_node("%Version").text, "v" + version)


# A web page's canvas starts tiny and grows after the menu is ready, which
# moves the centred buttons without resizing them.
func test_card_follows_the_buttons_when_the_screen_grows() -> void:
	var screen: Control = Control.new()
	screen.size = Vector2(320, 240)
	add_child_autofree(screen)
	var menu: Control = MENU_SCENE.instantiate()
	screen.add_child(menu)
	await wait_process_frames(2)
	screen.size = Vector2(1280, 960)
	await wait_process_frames(2)
	var buttons: Control = menu.get_node("GameButtons")
	var card: Control = menu.get_node("%Card")
	assert_almost_eq(card.get_rect().get_center(), buttons.get_rect().get_center(), Vector2.ONE)
