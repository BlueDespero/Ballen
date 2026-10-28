class_name PreMatchPanel
extends PanelContainer

## The pre-match overlay on the board: the player taps one rule of their deck
## to make it true, then the coin-toss result is shown for a moment. It only
## reports the player's choice; the scene sets up the match.

signal rule_chosen(rule: Rule)

## How long the coin-toss result stays up before the match starts.
const COIN_TOSS_SECONDS: float = 2.0
const BUTTON_HEIGHT: float = 52.0
const HOVER_BORDER_COLOUR: Color = RulesPanel.TRUE_BORDER_COLOUR

@onready var _choice: VBoxContainer = %Choice
@onready var _rule_buttons: VBoxContainer = %RuleButtons
@onready var _coin_toss: VBoxContainer = %CoinToss
@onready var _coin_title: Label = %CoinTitle
@onready var _coin_detail: Label = %CoinDetail
@onready var _timer: Timer = %Timer


## Shows the player's deck as buttons, one per rule.
func show_deck(deck: Deck) -> void:
	for child: Node in _rule_buttons.get_children():
		child.queue_free()
	for rule: Rule in deck.rules:
		_rule_buttons.add_child(_button(rule))
	_choice.visible = true
	_coin_toss.visible = false
	visible = true


## Shows who goes first, waits COIN_TOSS_SECONDS, then hides. A coroutine.
## In a rematch no coin is tossed: the other player goes first.
func show_coin_toss(player_goes_first: bool, is_rematch: bool = false) -> void:
	_choice.visible = false
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


func _button(rule: Rule) -> Button:
	var button: Button = Button.new()
	button.name = rule.id
	button.text = "%s    %s" % [rule.id, rule.text]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = BUTTON_HEIGHT
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_stylebox_override("normal", _style(RulesPanel.ROW_COLOUR, 0))
	button.add_theme_stylebox_override("hover", _style(RulesPanel.ROW_COLOUR.lightened(0.1), 2))
	button.add_theme_stylebox_override("pressed", _style(RulesPanel.TRUE_ROW_COLOUR, 2))
	button.pressed.connect(rule_chosen.emit.bind(rule))
	return button


func _style(colour: Color, border: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = colour
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.set_border_width_all(border)
	style.border_color = HOVER_BORDER_COLOUR
	return style
