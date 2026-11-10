extends GutTest

# The Android preset builds what Google Play accepts: an App Bundle with the
# package name that can never change, the target SDK Play requires, no
# permissions, uncompressed native libraries (16 KB page alignment), the
# launcher icons, and none of the development files.

const PRESETS_PATH: String = "res://export_presets.cfg"
const PACKAGE_NAME: String = "io.github.bluedespero.ballen"
## Google Play: new apps and updates target Android 16 (API 36) since August 2026.
const PLAY_TARGET_SDK: int = 36
## Godot 4.7's default when the preset leaves target_sdk empty.
const GODOT_DEFAULT_TARGET_SDK: int = 36
const DEV_FILES: Array[String] = ["test/*", "harness/*", "addons/gut/*", "docs/*", ".claude/*", "web-test/*"]

var _presets: ConfigFile


func before_all() -> void:
	_presets = ConfigFile.new()
	assert_eq(_presets.load(PRESETS_PATH), OK)


func _section(preset_name: String) -> String:
	for section: String in _presets.get_sections():
		if _presets.get_value(section, "name", "") == preset_name:
			return section
	return ""


func _option(key: String) -> Variant:
	return _presets.get_value(_section("Android") + ".options", key)


func test_there_is_an_android_preset() -> void:
	assert_eq(_presets.get_value(_section("Android"), "platform", ""), "Android")


func test_it_builds_an_app_bundle_with_gradle() -> void:
	assert_true(_option("gradle_build/use_gradle_build"))
	assert_eq(_option("gradle_build/export_format"), 1, "AAB")
	assert_false(_option("gradle_build/compress_native_libraries"), "16 KB alignment needs them uncompressed")


func test_it_targets_the_sdk_play_requires() -> void:
	var target: String = _option("gradle_build/target_sdk")
	var effective: int = GODOT_DEFAULT_TARGET_SDK if target.is_empty() else target.to_int()
	assert_gte(effective, PLAY_TARGET_SDK)


func test_it_keeps_the_package_name() -> void:
	assert_eq(_option("package/unique_name"), PACKAGE_NAME)
	assert_eq(_option("package/name"), "Ballen")
	assert_eq(_option("package/app_category"), 2, "Game")


func test_it_asks_for_no_permissions() -> void:
	assert_false(_option("permissions/internet"))
	assert_eq(_option("permissions/custom_permissions"), PackedStringArray())
	for key: String in _presets.get_section_keys(_section("Android") + ".options"):
		if key.begins_with("permissions/") and key != "permissions/custom_permissions":
			assert_false(_option(key), key)


func test_it_builds_for_phones_only() -> void:
	assert_true(_option("architectures/arm64-v8a"))
	assert_true(_option("architectures/armeabi-v7a"))
	assert_false(_option("architectures/x86"))
	assert_false(_option("architectures/x86_64"))


func test_the_launcher_icons_exist_at_their_sizes() -> void:
	var sizes: Dictionary = {
		"launcher_icons/main_192x192": 192,
		"launcher_icons/adaptive_foreground_432x432": 432,
		"launcher_icons/adaptive_background_432x432": 432,
		"launcher_icons/adaptive_monochrome_432x432": 432,
	}
	for key: String in sizes:
		var path: String = _option(key)
		var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		assert_not_null(image, key)
		if image != null:
			assert_eq(image.get_size(), Vector2i(sizes[key], sizes[key]), key)


func test_android_textures_can_be_imported() -> void:
	assert_true(ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc"),
		"Godot refuses to export for Android without ETC2/ASTC")


func test_no_preset_ships_the_development_files() -> void:
	for preset_name: String in ["Web", "Android"]:
		var excluded: String = _presets.get_value(_section(preset_name), "exclude_filter", "")
		for pattern: String in DEV_FILES:
			assert_string_contains(excluded, pattern, preset_name)
