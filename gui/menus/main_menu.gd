extends Control

## The main menu: the game's title over the board backdrop, and the buttons on
## a dark card so they stay readable over the falling balls. The game's version
## sits in the bottom-right corner, so a build can be traced.

const SETTINGS_SCENE: String = "res://gui/menus/settings_menu.tscn"
const DECKS_SCENE: String = "res://gui/menus/decks_screen.tscn"
const TITLE: String = "Ballen"
## The title's letters take the ball colours in turn, lightened so blue
## reads on the dark backdrop.
const TITLE_COLOURS: Array[String] = [BallColour.RED, BallColour.YELLOW, BallColour.GREEN, BallColour.BLUE]
const TITLE_LIGHTEN: float = 0.3
const TITLE_FONT_SIZE: int = 80
const TITLE_OUTLINE_SIZE: int = 14
const TITLE_OUTLINE_COLOUR: Color = Color(0.06, 0.07, 0.09)
const TITLE_GAP: float = 8.0
## The card reaches this far past the buttons on every side.
const CARD_MARGIN: float = 24.0

@onready var _title: HBoxContainer = %Title
@onready var _card: Panel = %Card
@onready var _buttons: VBoxContainer = $GameButtons
@onready var _version: Label = %Version


func _ready() -> void:
	_build_title()
	_version.text = "v" + str(ProjectSettings.get_setting("application/config/version"))
	_buttons.resized.connect(_place_card)
	_title.resized.connect(_place_card)
	Settings.changed.connect(_apply_text_scale)
	_apply_text_scale()


func _on_single_player_button_pressed() -> void:
	get_tree().change_scene_to_file("res://main_game.tscn")
	queue_free()


func _on_decks_button_pressed() -> void:
	get_tree().change_scene_to_file(DECKS_SCENE)


func _on_option_button_pressed() -> void:
	get_tree().change_scene_to_file(SETTINGS_SCENE)


## One label per letter, so each can take a ball colour.
func _build_title() -> void:
	var font: FontVariation = FontVariation.new()
	font.variation_embolden = 0.6
	for i: int in TITLE.length():
		var letter: Label = Label.new()
		letter.text = TITLE[i]
		var colour: Color = Constants.colors[TITLE_COLOURS[i % TITLE_COLOURS.size()]]["rgb"]
		letter.add_theme_color_override("font_color", colour.lightened(TITLE_LIGHTEN))
		letter.add_theme_color_override("font_outline_color", TITLE_OUTLINE_COLOUR)
		letter.add_theme_constant_override("outline_size", TITLE_OUTLINE_SIZE)
		letter.add_theme_font_override("font", font)
		letter.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
		letter.mouse_filter = MOUSE_FILTER_IGNORE
		_title.add_child(letter)


## The card sits behind the buttons, the title just above it; both follow the
## buttons when larger text resizes them.
func _place_card() -> void:
	_card.position = _buttons.position - Vector2.ONE * CARD_MARGIN
	_card.size = _buttons.size + Vector2.ONE * CARD_MARGIN * 2.0
	_title.size = _title.get_combined_minimum_size()
	_title.position = Vector2(_card.get_rect().get_center().x - _title.size.x / 2.0,
		_card.position.y - TITLE_GAP - _title.size.y)


## Larger text.
func _apply_text_scale() -> void:
	TextScale.apply(self, Settings.text_scale())
	_place_card()
