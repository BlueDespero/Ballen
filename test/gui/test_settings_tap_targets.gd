extends GutTest

# Everything tappable on the Settings screen and its Credits is at least a
# 44 px tap target, and each card still fits the 720 px screen with Larger text.

const SETTINGS_SCENE: PackedScene = preload("res://gui/menus/settings_menu.tscn")
const TAP_TARGET: float = 44.0
const SCREEN_HEIGHT: float = 720.0

var _larger_text: bool


func before_each() -> void:
	_larger_text = Settings.larger_text


func after_each() -> void:
	Settings.larger_text = _larger_text


func test_every_control_is_a_tap_target() -> void:
	var menu: Control = SETTINGS_SCENE.instantiate()
	add_child_autofree(menu)
	menu.get_node("%CreditsCard").visible = true
	await wait_process_frames(2)
	for control: Control in _tappables(menu):
		assert_gte(control.size.y, TAP_TARGET, String(control.name))


func test_the_cards_fit_the_screen_with_larger_text() -> void:
	Settings.larger_text = true
	var menu: Control = SETTINGS_SCENE.instantiate()
	add_child_autofree(menu)
	# A hidden card isn't laid out, so its wrapped text has no height yet.
	menu.get_node("%CreditsCard").visible = true
	await wait_process_frames(2)
	for card: String in ["Centre/Card", "%CreditsCard"]:
		var height: float = (menu.get_node(card) as Control).get_combined_minimum_size().y
		assert_lte(height, SCREEN_HEIGHT, "%s is %d px" % [card, height])


func _tappables(root: Node) -> Array[Control]:
	var found: Array[Control] = []
	for node: Node in root.find_children("*", "", true, false):
		if node is BaseButton or node is Slider:
			found.append(node as Control)
	return found
