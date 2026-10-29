extends Control

## The Settings screen, opened by the main menu's Options button. Every change
## goes straight into the Settings autoload and is saved at once; Back (or
## Escape) returns to the main menu. Credits swaps the card for the credits
## (Kenney and the engine) until its Back or Escape; the credits' Licences
## opens the licence notices (the engine's and the bundled font's) the same way.

const MAIN_MENU_SCENE: String = "res://main.tscn"
const PREVIEW_BALL_SIZE: float = 40.0
const PREVIEW_GAP: float = 12.0
const HEADING_SIZE: int = 20
const SUBHEADING_SIZE: int = 18
## The engine's own entry in its copyright info; its licence is shown first.
const ENGINE_COMPONENT: String = "Godot Engine"
## The symbol font the default font falls back on (`SymbolFont`), and its licence.
const BUNDLED_FONT: String = "Noto Sans Symbols, by the Noto Project Authors, under the SIL Open Font License 1.1."
const BUNDLED_FONT_LICENCE: String = "res://assets/fonts/OFL.txt"

@onready var _volume: HSlider = %Volume
@onready var _volume_value: Label = %VolumeValue
@onready var _symbol_preview: Control = %SymbolPreview
@onready var _settings_card: Control = $Centre/Card
@onready var _credits_card: Control = %CreditsCard
@onready var _licences_card: Control = %LicencesCard
@onready var _licences_list: Control = %LicencesList


func _ready() -> void:
	_volume.value = roundf(Settings.volume * 100.0)
	_show_volume(_volume.value)
	_volume.value_changed.connect(_on_volume_changed)
	_bind(%ColourBlindSymbols, "colour_blind_symbols")
	_bind(%ReducedMotion, "reduced_motion")
	_bind(%GuessWithoutHolding, "guess_without_holding")
	_bind(%LargerText, "larger_text")
	_symbol_preview.custom_minimum_size = Vector2(
		(PREVIEW_BALL_SIZE + PREVIEW_GAP) * BallColour.ALL.size() - PREVIEW_GAP, PREVIEW_BALL_SIZE)
	_symbol_preview.draw.connect(_draw_symbol_preview)
	Settings.changed.connect(_symbol_preview.queue_redraw)
	Settings.changed.connect(_apply_text_scale)
	_apply_text_scale()
	%Back.pressed.connect(_on_back_pressed)
	%Credits.pressed.connect(_show_credits.bind(true))
	%CreditsBack.pressed.connect(_show_credits.bind(false))
	%Licences.pressed.connect(_show_licences.bind(true))
	%LicencesBack.pressed.connect(_show_licences.bind(false))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _licences_card.visible:
			_show_licences(false)
		elif _credits_card.visible:
			_show_credits(false)
		else:
			_on_back_pressed()


## A switch for one on/off setting (a property of the Settings autoload).
func _bind(check: CheckButton, setting: String) -> void:
	check.button_pressed = Settings.get(setting)
	check.toggled.connect(_on_toggled.bind(setting))


func _on_toggled(on: bool, setting: String) -> void:
	Settings.set(setting, on)
	Settings.save_settings()


func _on_volume_changed(percent: float) -> void:
	_show_volume(percent)
	Settings.volume = percent / 100.0
	Settings.save_settings()


func _show_volume(percent: float) -> void:
	_volume_value.text = "%d%%" % int(percent)


## The four ball colours as they look on the board now.
func _draw_symbol_preview() -> void:
	for i: int in BallColour.ALL.size():
		var rect: Rect2 = Rect2(Vector2(i * (PREVIEW_BALL_SIZE + PREVIEW_GAP), 0.0), Vector2.ONE * PREVIEW_BALL_SIZE)
		BoardView.draw_ball(_symbol_preview, rect, BallColour.ALL[i], false, Settings.colour_blind_symbols)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


## Larger text applies to this screen as soon as it is switched.
func _apply_text_scale() -> void:
	TextScale.apply(self, Settings.text_scale())


func _show_credits(on: bool) -> void:
	_credits_card.visible = on
	_settings_card.visible = not on


func _show_licences(on: bool) -> void:
	if on and _licences_list.get_child_count() == 0:
		_fill_licences()
	_licences_card.visible = on
	_credits_card.visible = not on


## The engine's own licence, then every third-party component it bundles and
## the full text of each licence they use, read from the running engine so the
## list matches the build. Filled on first open: it is long.
func _fill_licences() -> void:
	_add_licence_label("Godot Engine", HEADING_SIZE)
	_add_licence_label(Engine.get_license_text())
	_add_licence_label("Third-party components in the engine", HEADING_SIZE)
	for component: Dictionary in Engine.get_copyright_info():
		if component["name"] == ENGINE_COMPONENT:
			continue
		var lines: PackedStringArray = [component["name"]]
		for part: Dictionary in component["parts"]:
			for holder: String in part["copyright"]:
				lines.append("© " + holder)
			lines.append(tr("Licence: %s") % part["license"])
		_add_licence_label("\n".join(lines))
	_add_licence_label("Bundled font", HEADING_SIZE)
	_add_licence_label(BUNDLED_FONT)
	_add_licence_label(FileAccess.get_file_as_string(BUNDLED_FONT_LICENCE))
	_add_licence_label("Licence texts", HEADING_SIZE)
	var texts: Dictionary = Engine.get_license_info()
	for licence: String in texts:
		_add_licence_label(licence, SUBHEADING_SIZE)
		_add_licence_label(texts[licence])
	TextScale.apply(_licences_list, Settings.text_scale())


func _add_licence_label(text: String, font_size: int = 0) -> void:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font_size > 0:
		label.add_theme_font_size_override("font_size", font_size)
	_licences_list.add_child(label)
