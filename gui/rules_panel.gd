class_name RulesPanel
extends PanelContainer

## The rules panel on the right: the AI's 5 rules on top, the player's 5 below
## with their true rule highlighted. The player selects one of the AI's rules
## by clicking it and names it by holding Guess under them. Slots are kept
## free for the skip pips beside each title.

## The player held Guess to the end with one of the AI's rules selected.
signal guess_requested(rule_id: String)

const ROW_HEIGHT: float = 44.0
const ROW_COLOUR: Color = Color(0.17, 0.19, 0.23)
const TRUE_ROW_COLOUR: Color = Color(0.33, 0.27, 0.1)
const TRUE_BORDER_COLOUR: Color = Color(1.0, 0.82, 0.3)
const SELECTED_ROW_COLOUR: Color = Color(0.16, 0.24, 0.34)
const SELECTED_BORDER_COLOUR: Color = Color(0.45, 0.72, 1.0)
const ID_COLOUR: Color = Color(0.6, 0.64, 0.7)
const HINT_COLOUR: Color = Color(0.7, 0.74, 0.8)

## Whether one of the player's guess windows is open; Guess also needs a
## selected rule.
var guess_enabled: bool = false:
	set(value):
		guess_enabled = value
		_update_guess()

## The id of the AI's rule the player selected; "" for none.
var selected_rule_id: String = ""

var _match_over: bool = false

@onready var _ai_rules: VBoxContainer = %AIRules
@onready var _player_rules: VBoxContainer = %PlayerRules
@onready var _guess_button: GuessButton = %GuessButton
@onready var _guess_hint: Label = %GuessHint


func _ready() -> void:
	_guess_button.guessed.connect(_on_guessed)
	_guess_hint.add_theme_color_override("font_color", HINT_COLOUR)
	_update_guess()


func show_decks(ai_deck: Deck, player_deck: Deck, player_true_rule: Rule) -> void:
	_fill(_ai_rules, ai_deck, null)
	_fill(_player_rules, player_deck, player_true_rule)
	for row: Node in _ai_rules.get_children():
		var panel: PanelContainer = row as PanelContainer
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		panel.gui_input.connect(_on_ai_row_input.bind(String(panel.name)))
	_select("")


## Once the match is over: marks the AI's true rule and closes guessing.
func show_match_over(ai_true_rule: Rule) -> void:
	if _match_over:
		return
	_match_over = true
	guess_enabled = false
	_select("")
	for row: Node in _ai_rules.get_children():
		var panel: PanelContainer = row as PanelContainer
		panel.mouse_default_cursor_shape = Control.CURSOR_ARROW
		if String(panel.name) == ai_true_rule.id:
			panel.add_theme_stylebox_override("panel", _style(false, true))
			panel.get_child(0).add_child(_label("TRUE", TRUE_BORDER_COLOUR))
	_update_guess()


## Clicking an AI rule selects it; clicking it again clears the selection.
func _on_ai_row_input(event: InputEvent, rule_id: String) -> void:
	if _match_over:
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
		_select("" if rule_id == selected_rule_id else rule_id)


func _select(rule_id: String) -> void:
	selected_rule_id = rule_id
	for row: Node in _ai_rules.get_children():
		var panel: PanelContainer = row as PanelContainer
		panel.add_theme_stylebox_override("panel", _style(String(panel.name) == rule_id, false))
	_update_guess()


func _on_guessed() -> void:
	if guess_enabled and selected_rule_id != "":
		guess_requested.emit(selected_rule_id)


func _update_guess() -> void:
	if not is_node_ready():
		return
	_guess_button.enabled = guess_enabled and selected_rule_id != ""
	_guess_button.visible = not _match_over
	if _match_over:
		_guess_hint.text = "The match is over. The AI's true rule is marked."
	elif not guess_enabled:
		_guess_hint.text = "You can guess at the start of your turn and until your colour pick."
	elif selected_rule_id == "":
		_guess_hint.text = "Select the rule you think is the AI's true rule."
	else:
		_guess_hint.text = "Hold Guess to name %s. Right wins, wrong loses." % selected_rule_id


func _fill(list: VBoxContainer, deck: Deck, true_rule: Rule) -> void:
	for child: Node in list.get_children():
		list.remove_child(child)
		child.queue_free()
	for rule: Rule in deck.rules:
		list.add_child(_row(rule, rule == true_rule))


func _row(rule: Rule, is_true: bool) -> PanelContainer:
	var row: PanelContainer = PanelContainer.new()
	row.name = rule.id
	row.custom_minimum_size.y = ROW_HEIGHT
	row.add_theme_stylebox_override("panel", _style(false, is_true))
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	var id_label: Label = _label(rule.id, ID_COLOUR)
	id_label.custom_minimum_size.x = 40
	line.add_child(id_label)
	var text_label: Label = _label(rule.text, Color.WHITE)
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.add_child(text_label)
	if is_true:
		line.add_child(_label("TRUE", TRUE_BORDER_COLOUR))
	return row


func _style(is_selected: bool, is_true: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = ROW_COLOUR
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	if is_true or is_selected:
		style.bg_color = TRUE_ROW_COLOUR if is_true else SELECTED_ROW_COLOUR
		style.set_border_width_all(2)
		style.border_color = TRUE_BORDER_COLOUR if is_true else SELECTED_BORDER_COLOUR
	return style


func _label(text: String, colour: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_FILL
	label.add_theme_color_override("font_color", colour)
	return label
