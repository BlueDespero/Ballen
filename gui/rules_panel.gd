class_name RulesPanel
extends PanelContainer

## The rules panel on the right: the AI's 5 rules on top, the player's 5 below
## with their true rule highlighted. Slots are kept free for the skip pips
## beside each title and the Guess button under the AI's rules.

const ROW_HEIGHT: float = 44.0
const ROW_COLOUR: Color = Color(0.17, 0.19, 0.23)
const TRUE_ROW_COLOUR: Color = Color(0.33, 0.27, 0.1)
const TRUE_BORDER_COLOUR: Color = Color(1.0, 0.82, 0.3)
const ID_COLOUR: Color = Color(0.6, 0.64, 0.7)

@onready var _ai_rules: VBoxContainer = %AIRules
@onready var _player_rules: VBoxContainer = %PlayerRules


func show_decks(ai_deck: Deck, player_deck: Deck, player_true_rule: Rule) -> void:
	_fill(_ai_rules, ai_deck, null)
	_fill(_player_rules, player_deck, player_true_rule)


func _fill(list: VBoxContainer, deck: Deck, true_rule: Rule) -> void:
	for child: Node in list.get_children():
		child.queue_free()
	for rule: Rule in deck.rules:
		list.add_child(_row(rule, rule == true_rule))


func _row(rule: Rule, is_true: bool) -> PanelContainer:
	var row: PanelContainer = PanelContainer.new()
	row.name = rule.id
	row.custom_minimum_size.y = ROW_HEIGHT
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = TRUE_ROW_COLOUR if is_true else ROW_COLOUR
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	if is_true:
		style.set_border_width_all(2)
		style.border_color = TRUE_BORDER_COLOUR
	row.add_theme_stylebox_override("panel", style)
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
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


func _label(text: String, colour: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_FILL
	label.add_theme_color_override("font_color", colour)
	return label
