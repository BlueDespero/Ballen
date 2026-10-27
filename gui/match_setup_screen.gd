class_name MatchSetupScreen
extends Control

## The match setup screen before a match: the player picks a saved deck and
## the AI level, taps one rule of the deck to make it true, then presses Start.
## A rematch comes back here with the same deck and level, so only the true
## rule is chosen again. The screen leaves the rules panel uncovered, so the
## scene can show both decks there while the player chooses. After Start the
## screen gives way to the board and shows who goes first for a moment. It only
## reports the player's choices; the scene sets up the match.

## The screen now shows this deck's rules to choose from.
signal deck_shown(deck: Deck)
## The player pressed Start with these choices.
signal start_requested(deck: Deck, level: AILevel.Level, true_rule: Rule)
## The player pressed Main menu.
signal main_menu_requested

## How long the coin-toss result stays up before the match starts.
const COIN_TOSS_SECONDS: float = 2.0
const RULE_BUTTON_HEIGHT: float = 44.0
const LEVEL_BUTTON_HEIGHT: float = 44.0
## Narrow, so three level buttons fit beside the caption with "(coming soon)".
const LEVEL_BUTTON_MARGIN: int = 6
const DEFAULT_LEVEL: AILevel.Level = AILevel.Level.NORMAL

## Larger text: the screen's text is this many times its built size.
var text_scale: float = 1.0:
	set(value):
		text_scale = value
		TextScale.apply(self, value)

@onready var _backdrop: ColorRect = %Backdrop
@onready var _title: Label = %Title
@onready var _deck_picker: OptionButton = %DeckPicker
@onready var _level_buttons: HBoxContainer = %LevelButtons
@onready var _level_description: Label = %LevelDescription
@onready var _rule_buttons: VBoxContainer = %RuleButtons
@onready var _start_button: Button = %StartButton
@onready var _main_menu_button: Button = %MainMenuButton
@onready var _coin_toss: PanelContainer = %CoinToss
@onready var _coin_title: Label = %CoinTitle
@onready var _coin_detail: Label = %CoinDetail
@onready var _timer: Timer = %Timer

var _store: DeckStore = null
var _deck: Deck = null
var _level: AILevel.Level = DEFAULT_LEVEL
var _true_rule: Rule = null
var _level_group: ButtonGroup = ButtonGroup.new()
var _rule_group: ButtonGroup = ButtonGroup.new()


func _ready() -> void:
	_deck_picker.item_selected.connect(_on_deck_selected)
	_start_button.pressed.connect(_on_start_pressed)
	_main_menu_button.pressed.connect(main_menu_requested.emit)
	_deck_picker.add_theme_stylebox_override("normal", _style(RulesPanel.ROW_COLOUR, 0))
	_deck_picker.add_theme_stylebox_override("hover", _style(RulesPanel.ROW_COLOUR.lightened(0.1), 2))
	_deck_picker.add_theme_stylebox_override("pressed", _style(RulesPanel.ROW_COLOUR.lightened(0.1), 2))
	_deck_picker.add_theme_stylebox_override("disabled", _style(RulesPanel.ROW_COLOUR, 0))
	for level: AILevel.Level in AILevel.ALL:
		_level_buttons.add_child(_level_button(level))


## Shows the setup for a new match: the saved decks to pick from (the first
## one picked), the AI levels, and the picked deck's rules.
func show_setup(store: DeckStore) -> void:
	_store = store
	_title.text = "Match setup"
	_deck_picker.clear()
	for deck_name: String in store.names():
		_deck_picker.add_item(deck_name)
	_deck_picker.select(0)
	_deck_picker.disabled = false
	_set_level_choice(true)
	_show_deck(store.deck(store.names()[0]))
	_show()


## Shows the setup for a rematch: the deck and level of the last match stay,
## and the player chooses a true rule again.
func show_rematch() -> void:
	_title.text = "Rematch"
	_deck_picker.disabled = true
	_set_level_choice(false)
	_show_deck(_deck)
	_show()


## Shows who goes first over the board, waits COIN_TOSS_SECONDS, then hides.
## A coroutine. In a rematch no coin is tossed: the other player goes first.
func show_coin_toss(player_goes_first: bool, is_rematch: bool = false) -> void:
	_backdrop.visible = false
	_coin_toss.visible = true
	var prefix: String = "Rematch" if is_rematch else "Coin toss"
	if player_goes_first:
		_coin_title.text = "%s: you go first" % prefix
		_coin_detail.text = "The AI picks the colour of your first ball."
	else:
		_coin_title.text = "%s: the AI goes first" % prefix
		_coin_detail.text = "You pick the colour of its first ball."
	_timer.start(COIN_TOSS_SECONDS)
	await _timer.timeout
	visible = false


func _show() -> void:
	_backdrop.visible = true
	_coin_toss.visible = false
	visible = true


## The deck's rules as buttons, none chosen yet. Old buttons are removed at
## once, so the new ones keep their rule-id names.
func _show_deck(deck: Deck) -> void:
	_deck = deck
	_true_rule = null
	_start_button.disabled = true
	for child: Node in _rule_buttons.get_children():
		_rule_buttons.remove_child(child)
		child.queue_free()
	for rule: Rule in deck.rules:
		_rule_buttons.add_child(_rule_button(rule))
	TextScale.apply(_rule_buttons, text_scale)
	deck_shown.emit(deck)


func _on_deck_selected(index: int) -> void:
	_show_deck(_store.deck(_deck_picker.get_item_text(index)))


func _on_level_chosen(level: AILevel.Level) -> void:
	_level = level
	_level_description.text = AILevel.description(level)


func _on_rule_chosen(rule: Rule) -> void:
	_true_rule = rule
	_start_button.disabled = false


func _on_start_pressed() -> void:
	if _true_rule != null:
		start_requested.emit(_deck, _level, _true_rule)


## Levels that are built can be picked unless locked (a rematch keeps the
## level, so only its button stays lit); the others say they are coming soon.
func _set_level_choice(can_change: bool) -> void:
	for button: Button in _level_buttons.get_children():
		var level: AILevel.Level = AILevel.ALL[button.get_index()]
		button.disabled = not AILevel.is_built(level) or (not can_change and level != _level)
		button.button_pressed = level == _level
	_level_description.text = AILevel.description(_level)


func _level_button(level: AILevel.Level) -> Button:
	var button: Button = Button.new()
	button.name = AILevel.title(level)
	button.text = AILevel.title(level) if AILevel.is_built(level) else "%s (coming soon)" % AILevel.title(level)
	button.toggle_mode = true
	button.button_group = _level_group
	button.custom_minimum_size.y = LEVEL_BUTTON_HEIGHT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 15)
	_style_choice(button, LEVEL_BUTTON_MARGIN)
	button.pressed.connect(_on_level_chosen.bind(level))
	return button


func _rule_button(rule: Rule) -> Button:
	var button: Button = Button.new()
	button.name = rule.id
	button.text = "%s    %s" % [rule.id, rule.text]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.toggle_mode = true
	button.button_group = _rule_group
	button.custom_minimum_size.y = RULE_BUTTON_HEIGHT
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 18)
	_style_choice(button)
	button.pressed.connect(_on_rule_chosen.bind(rule))
	return button


## A choice button: a plain row, outlined on hover, gold once chosen (like the
## true rule in the rules panel), dimmed when it can't be chosen.
func _style_choice(button: Button, margin: int = 16) -> void:
	var chosen: StyleBoxFlat = _style(RulesPanel.TRUE_ROW_COLOUR, 2, margin)
	button.add_theme_stylebox_override("normal", _style(RulesPanel.ROW_COLOUR, 0, margin))
	button.add_theme_stylebox_override("hover", _style(RulesPanel.ROW_COLOUR.lightened(0.1), 2, margin))
	button.add_theme_stylebox_override("pressed", chosen)
	button.add_theme_stylebox_override("hover_pressed", chosen)
	button.add_theme_stylebox_override("disabled", _style(RulesPanel.ROW_COLOUR.darkened(0.3), 0, margin))
	button.add_theme_color_override("font_disabled_color", RulesPanel.ID_COLOUR.darkened(0.2))
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_hover_pressed_color", Color.WHITE)


func _style(colour: Color, border: int, margin: int = 16) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = colour
	style.set_corner_radius_all(8)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.set_border_width_all(border)
	style.border_color = RulesPanel.TRUE_BORDER_COLOUR
	return style
