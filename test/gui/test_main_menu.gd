extends GutTest

# The main menu shows the game's version in a corner, so a build can be traced.

const MENU_SCENE: PackedScene = preload("res://gui/menus/main_menu.tscn")


func test_version_label_shows_the_project_version() -> void:
	var menu: Control = MENU_SCENE.instantiate()
	add_child_autofree(menu)
	var version: String = ProjectSettings.get_setting("application/config/version")
	assert_ne(version, "", "project.godot sets a version")
	assert_eq(menu.get_node("%Version").text, "v" + version)
