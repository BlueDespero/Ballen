extends GutTest

# The Polish translation (locale/pl.po, keyed on the English text) covers every
# text a player sees, and keeps each text's %s and %d blanks.

const POLISH_PATH: String = "res://locale/pl.po"
## Scene properties that show text and are translated.
const TEXT_PROPERTIES: Array[StringName] = [&"text", &"placeholder_text", &"tooltip_text", &"label"]
## Scene texts the scripts always replace before they show.
const PLACEHOLDERS: Array[String] = ["Status", "Rule text", "R00"]
const SKIPPED_DIRS: Array[String] = ["res://addons", "res://test", "res://.godot", "res://.claude"]

var _polish: Translation


func before_all() -> void:
	_polish = load(POLISH_PATH)


func after_each() -> void:
	TranslationServer.set_locale(GameSettings.ENGLISH)


func test_the_polish_translation_is_registered() -> void:
	var registered: PackedStringArray = ProjectSettings.get_setting("internationalization/locale/translations", [])
	assert_has(registered, POLISH_PATH)
	assert_eq(_polish.locale, GameSettings.POLISH)


func test_every_scene_text_has_a_polish_translation() -> void:
	var missing: PackedStringArray = []
	var scenes: PackedStringArray = _scenes("res://")
	assert_has(scenes, "res://gui/menus/settings_menu.tscn", "the menus are among the scenes checked")
	for path: String in scenes:
		var state: SceneState = (load(path) as PackedScene).get_state()
		for node: int in state.get_node_count():
			if _never_translated(state, node):
				continue
			for i: int in state.get_node_property_count(node):
				var value: Variant = state.get_node_property_value(node, i)
				if TEXT_PROPERTIES.has(state.get_node_property_name(node, i)) and _needs_translation(value):
					if _polish.get_message(value) == "":
						missing.append("%s: %s" % [path, value])
	assert_eq(missing, PackedStringArray(), "scene texts without a Polish translation")


func test_every_rule_has_a_polish_translation() -> void:
	var book: RuleBook = RuleBook.load_default()
	for rule_id: String in book.rule_ids():
		assert_ne(_polish.get_message(book.rule(rule_id).text), "", rule_id)


func test_names_built_in_code_have_polish_translations() -> void:
	var texts: Array[String] = []
	for level: AILevel.Level in AILevel.ALL:
		texts.append_array([AILevel.title(level), AILevel.description(level)])
	for tier: String in Rule.TIERS:
		texts.append(TierBadge.title(tier))
	for colour: String in BallColour.ALL:
		texts.append(colour.capitalize())
		assert_ne(_polish.get_message(colour, BallColour.BALL_CONTEXT), "", colour + " in a sentence about a ball")
	for text: String in texts:
		assert_ne(_polish.get_message(text), "", text)


func test_translations_keep_the_blanks_in_order() -> void:
	var blank: RegEx = RegEx.create_from_string("%[sd]")
	for id: String in _polish.get_message_list():
		var english: PackedStringArray = []
		for found: RegExMatch in blank.search_all(id):
			english.append(found.get_string())
		var polish: PackedStringArray = []
		for found: RegExMatch in blank.search_all(_polish.get_message(id)):
			polish.append(found.get_string())
		assert_eq(polish, english, id)


func test_in_polish_the_game_text_is_polish() -> void:
	TranslationServer.set_locale(GameSettings.POLISH)
	assert_eq(tr("Single Player"), "Gra jednoosobowa")
	assert_eq(BallColour.word(BallColour.RED), "czerwona")
	TranslationServer.set_locale(GameSettings.ENGLISH)
	assert_eq(tr("Single Player"), "Single Player")
	assert_eq(BallColour.word(BallColour.RED), "red")


## A node that keeps its text in every language (a language's own name).
func _never_translated(state: SceneState, node: int) -> bool:
	for i: int in state.get_node_property_count(node):
		if state.get_node_property_name(node, i) == &"auto_translate_mode":
			return state.get_node_property_value(node, i) == Node.AUTO_TRANSLATE_MODE_DISABLED
	return false


## Text worth translating: words, not a placeholder, a number or a web address.
func _needs_translation(value: Variant) -> bool:
	if not value is String or PLACEHOLDERS.has(value):
		return false
	var text: String = value
	return RegEx.create_from_string("[A-Za-z]{2}").search(text) != null and not text.contains(".org") \
		and not text.begins_with("www.")


func _scenes(dir: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".tscn"):
			found.append(dir.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir):
		var path: String = dir.path_join(sub)
		if not SKIPPED_DIRS.has(path):
			found.append_array(_scenes(path))
	return found
