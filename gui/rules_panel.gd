class_name RulesPanel
extends PanelContainer

## The rules panel on the right: the AI's 5 rules on top, the player's 5 below
## with their true rule highlighted, and each side's skip pips beside its
## title. The player selects one of the AI's rules by clicking it and names it
## by holding Guess under them. On a full board, holding Seal beside Guess
## makes the player's sealed forced guess instead.

## The player held Guess to the end with one of the AI's rules selected.
signal guess_requested(rule_id: String)
## The player held Seal to the end with one of the AI's rules selected.
signal seal_requested(rule_id: String)

const ROW_HEIGHT: float = 44.0
const ROW_COLOUR: Color = Color(0.17, 0.19, 0.23)
const TRUE_ROW_COLOUR: Color = Color(0.33, 0.27, 0.1)
const TRUE_BORDER_COLOUR: Color = Color(1.0, 0.82, 0.3)
const SELECTED_ROW_COLOUR: Color = Color(0.16, 0.24, 0.34)
const SELECTED_BORDER_COLOUR: Color = Color(0.45, 0.72, 1.0)
const ID_COLOUR: Color = Color(0.6, 0.64, 0.7)
const HINT_COLOUR: Color = Color(0.7, 0.74, 0.8)
const PIP_SIZE: float = 16.0
const PIP_FILLED_COLOUR: Color = Color(0.92, 0.36, 0.32)
const PIP_EMPTY_COLOUR: Color = Color(0.6, 0.64, 0.7)

## Whether one of the player's guess windows is open; Guess also needs a
## selected rule.
var guess_enabled: bool = false:
	set(value):
		guess_enabled = value
		_update_guess()

## Whether the player's forced guess is due, so Seal is offered; Seal also
## needs a selected rule.
var seal_enabled: bool = false:
	set(value):
		seal_enabled = value
		_update_guess()

## Whether the board is full (the match is in its forced guesses).
var board_full: bool = false:
	set(value):
		board_full = value
		_update_guess()

## The id of the AI's rule the player selected; "" for none.
var selected_rule_id: String = ""

var _match_over: bool = false

@onready var _ai_rules: VBoxContainer = %AIRules
@onready var _player_rules: VBoxContainer = %PlayerRules
@onready var _guess_button: GuessButton = %GuessButton
@onready var _seal_button: GuessButton = %SealButton
@onready var _guess_hint: Label = %GuessHint
@onready var _ai_skip_pips: HBoxContainer = %AISkipPips
@onready var _player_skip_pips: HBoxContainer = %PlayerSkipPips


func _ready() -> void:
	_guess_button.guessed.connect(_on_guessed)
	_seal_button.guessed.connect(_on_sealed)
	_guess_hint.add_theme_color_override("font_color", HINT_COLOUR)
	_update_guess()


## Shows both decks for a new match (also a rematch: the match-over marks go).
func show_decks(ai_deck: Deck, player_deck: Deck, player_true_rule: Rule) -> void:
	_match_over = false
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
	seal_enabled = false
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


func _on_sealed() -> void:
	if seal_enabled and selected_rule_id != "":
		seal_requested.emit(selected_rule_id)


## On a full board Guess shows only while the player (the placer) may still
## guess outright, and Seal only while their forced guess is due.
func _update_guess() -> void:
	if not is_node_ready():
		return
	_guess_button.enabled = guess_enabled and selected_rule_id != ""
	_guess_button.visible = not _match_over and (guess_enabled or not board_full)
	_seal_button.enabled = seal_enabled and selected_rule_id != ""
	_seal_button.visible = not _match_over and board_full and seal_enabled
	if _match_over:
		_guess_hint.text = "The match is over. The AI's true rule is marked."
	elif board_full and not guess_enabled and not seal_enabled:
		_guess_hint.text = "The board is full. Both forced guesses are revealed together."
	elif not guess_enabled and not seal_enabled:
		_guess_hint.text = "You can guess at the start of your turn and until your colour pick."
	elif selected_rule_id == "":
		_guess_hint.text = "Select the rule you think is the AI's true rule."
	elif guess_enabled and seal_enabled:
		_guess_hint.text = "Hold Guess to name %s now (right wins, wrong loses), or Seal for your forced guess." % selected_rule_id
	elif seal_enabled:
		_guess_hint.text = "Hold Seal to seal %s as your forced guess. One right guess wins; else a draw." % selected_rule_id
	else:
		_guess_hint.text = "Hold Guess to name %s. Right wins, wrong loses." % selected_rule_id


## One pip per skip that loses the match, filled for each skip taken.
func show_skips(ai_skips: int, player_skips: int) -> void:
	_fill_pips(_ai_skip_pips, ai_skips)
	_fill_pips(_player_skip_pips, player_skips)


func _fill_pips(pips: HBoxContainer, skips: int) -> void:
	for child: Node in pips.get_children():
		pips.remove_child(child)
		child.queue_free()
	for i: int in Match.LOSING_SKIP:
		pips.add_child(_pip(i < skips))


func _pip(filled: bool) -> Panel:
	var pip: Panel = Panel.new()
	pip.custom_minimum_size = Vector2(PIP_SIZE, PIP_SIZE)
	pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.set_corner_radius_all(int(PIP_SIZE / 2.0))
	style.set_border_width_all(2)
	style.border_color = PIP_FILLED_COLOUR if filled else PIP_EMPTY_COLOUR
	style.bg_color = PIP_FILLED_COLOUR if filled else Color.TRANSPARENT
	pip.add_theme_stylebox_override("panel", style)
	return pip


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
