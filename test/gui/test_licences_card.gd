extends GutTest

# Credits' Licences card lists the engine's licence and its bundled
# third-party components, read from the running engine.

const SETTINGS_SCENE: PackedScene = preload("res://gui/menus/settings_menu.tscn")


func test_licences_card_shows_the_godot_licence_and_third_party_components() -> void:
	var menu: Control = SETTINGS_SCENE.instantiate()
	add_child_autofree(menu)
	menu.get_node("%Credits").pressed.emit()
	menu.get_node("%Licences").pressed.emit()
	assert_true(menu.get_node("%LicencesCard").visible, "Licences opens its card")
	var text: String = _text_under(menu.get_node("%LicencesList"))
	assert_string_contains(text, Engine.get_license_text())
	var component: String = _first_third_party_component()
	assert_ne(component, "", "the engine bundles third-party components")
	assert_string_contains(text, component)


func test_back_returns_from_licences_to_credits() -> void:
	var menu: Control = SETTINGS_SCENE.instantiate()
	add_child_autofree(menu)
	menu.get_node("%Credits").pressed.emit()
	menu.get_node("%Licences").pressed.emit()
	menu.get_node("%LicencesBack").pressed.emit()
	assert_false(menu.get_node("%LicencesCard").visible)
	assert_true(menu.get_node("%CreditsCard").visible)


func _first_third_party_component() -> String:
	for component: Dictionary in Engine.get_copyright_info():
		if component["name"] != "Godot Engine":
			return component["name"]
	return ""


func _text_under(root: Node) -> String:
	var parts: PackedStringArray = []
	for node: Node in root.find_children("*", "Label", true, false):
		parts.append((node as Label).text)
	return "\n".join(parts)
