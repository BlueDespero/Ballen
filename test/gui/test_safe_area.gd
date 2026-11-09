extends GutTest

# In the phone and tablet apps the current scene keeps clear of the camera
# cutout: SafeArea maps the display's safe area (screen pixels) into the
# viewport and insets the scene's root to it.

const SafeAreaScript: GDScript = preload("res://gui/safe_area.gd")
## A 2400 × 1080 phone shows a 1600 × 720 viewport (canvas_items, expand).
const PHONE: Rect2i = Rect2i(0, 0, 2400, 1080)
const VIEWPORT: Vector2 = Vector2(1600, 720)


func test_no_cutout_keeps_the_whole_viewport() -> void:
	assert_eq(SafeAreaScript.safe_rect(PHONE, PHONE, VIEWPORT), Rect2(Vector2.ZERO, VIEWPORT))


func test_a_cutout_on_the_left_insets_the_left_edge() -> void:
	var safe: Rect2i = Rect2i(120, 0, 2280, 1080)
	assert_eq(SafeAreaScript.safe_rect(PHONE, safe, VIEWPORT), Rect2(80, 0, 1520, 720))


func test_a_cutout_on_the_right_insets_the_right_edge() -> void:
	var safe: Rect2i = Rect2i(0, 0, 2280, 1080)
	assert_eq(SafeAreaScript.safe_rect(PHONE, safe, VIEWPORT), Rect2(0, 0, 1520, 720))


# A window that already leaves the cutout out (not drawn edge to edge) needs
# no further inset.
func test_a_window_beside_the_cutout_is_all_safe() -> void:
	var window: Rect2i = Rect2i(120, 0, 2280, 1080)
	var safe: Rect2i = Rect2i(120, 0, 2280, 1080)
	var visible_size: Vector2 = Vector2(1520, 720)
	assert_eq(SafeAreaScript.safe_rect(window, safe, visible_size), Rect2(Vector2.ZERO, visible_size))


func test_no_overlap_falls_back_to_the_whole_viewport() -> void:
	var safe: Rect2i = Rect2i(3000, 0, 100, 100)
	assert_eq(SafeAreaScript.safe_rect(PHONE, safe, VIEWPORT), Rect2(Vector2.ZERO, VIEWPORT))


func test_fit_insets_a_full_screen_control() -> void:
	var control: Control = add_child_autofree(Control.new())
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	SafeAreaScript.fit(control, Rect2(80, 0, 1520, 720), VIEWPORT)
	assert_eq([control.offset_left, control.offset_top, control.offset_right, control.offset_bottom],
		[80.0, 0.0, 0.0, 0.0])
	SafeAreaScript.fit(control, Rect2(0, 0, 1520, 720), VIEWPORT)
	assert_eq([control.offset_left, control.offset_top, control.offset_right, control.offset_bottom],
		[0.0, 0.0, -80.0, 0.0])


# Every scene is a full-screen root, which is what fit insets.
func test_every_scene_root_fills_the_screen() -> void:
	for path: String in ["res://main.tscn", "res://main_game.tscn", "res://gui/menus/settings_menu.tscn",
			"res://gui/menus/decks_screen.tscn"]:
		var scene: Control = (load(path) as PackedScene).instantiate()
		assert_eq([scene.anchor_left, scene.anchor_top, scene.anchor_right, scene.anchor_bottom],
			[0.0, 0.0, 1.0, 1.0], path)
		scene.free()
