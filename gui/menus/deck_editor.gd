class_name DeckEditor
extends Control

## The deck editor, opened by the Decks screen over itself: a name, a "3 / 5"
## counter and every built rule as a row to pick (id, text, tier badge), with
## chips to show one tier only. The DeckDraft holds the picks and says what
## stops a save (the hint line); a sixth pick does nothing but flash the
## counter. Save and Cancel (or Escape) close it.

## The player saved the draft (saved true) or cancelled (false).
signal closed(saved: bool)

const ALL_TIERS: String = ""
const ROW_HEIGHT: float = 48.0
const NAME_FONT_SIZE: int = 20
const FLASH_COLOUR: Color = Color(1.0, 0.45, 0.4)
const FLASH_SECONDS: float = 0.6
const CHIP_HEIGHT: float = 36.0
## Chips grow with their text (Larger text) beyond this width.
const CHIP_WIDTH: float = 112.0
const CHIP_MARGIN: float = 18.0

@onready var _title: Label = %Title
@onready var _name_field: LineEdit = %NameField
@onready var _counter: Label = %Counter
@onready var _chips: HBoxContainer = %Chips
@onready var _rule_list: VBoxContainer = %RuleList
@onready var _hint: Label = %Hint
@onready var _save_button: Button = %SaveButton
@onready var _cancel_button: Button = %CancelButton

var _draft: DeckDraft = DeckDraft.new()
var _store: DeckStore = null
var _book: RuleBook = null
var _shown_tier: String = ALL_TIERS
var _hovered_rule_id: String = ""
var _chip_group: ButtonGroup = ButtonGroup.new()
var _flash: Tween = null


func _ready() -> void:
	_name_field.text_changed.connect(_on_name_changed)
	_name_field.text_submitted.connect(func(_text: String) -> void: _on_save_pressed())
	_save_button.pressed.connect(_on_save_pressed)
	_cancel_button.pressed.connect(closed.emit.bind(false))
	for tier: String in [ALL_TIERS] + Array(Rule.TIERS):
		_chips.add_child(_chip(tier))
	Settings.changed.connect(_apply_text_scale)
	_apply_text_scale()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit(false)


## Shows the draft to edit: titled title, every rule of the book to pick from,
## saving to store.
func open(draft: DeckDraft, store: DeckStore, book: RuleBook, title: String) -> void:
	_draft = draft
	_store = store
	_book = book
	_title.text = title
	_name_field.text = draft.name
	for child: Node in _rule_list.get_children():
		_rule_list.remove_child(child)
		child.queue_free()
	for rule_id: String in book.rule_ids():
		_rule_list.add_child(_rule_row(book.rule(rule_id)))
	_apply_text_scale()
	_refresh()


func _on_name_changed(text: String) -> void:
	_draft.name = text
	_refresh()


## Save, or Enter in the name field; nothing while Save is disabled.
func _on_save_pressed() -> void:
	if _save_button.disabled:
		return
	if _draft.save_to(_store, _book):
		closed.emit(true)


func _toggle(rule_id: String) -> void:
	if not _draft.toggle(rule_id):
		_flash_counter()
	_refresh()


func _show_tier(tier: String) -> void:
	_shown_tier = tier
	for row: Control in _rule_list.get_children():
		row.visible = tier == ALL_TIERS or _book.rule(row.name).tier == tier


func _refresh() -> void:
	_counter.text = "%d / %d" % [_draft.count(), Deck.SIZE]
	var problem: String = _draft.problem(_store)
	_hint.text = problem
	_save_button.disabled = problem != ""
	for row: PanelContainer in _rule_list.get_children():
		_style_row(row)


## The counter turns red and fades back: the deck is full.
func _flash_counter() -> void:
	if _flash != null:
		_flash.kill()
	_counter.modulate = FLASH_COLOUR
	_flash = create_tween()
	_flash.tween_property(_counter, "modulate", Color.WHITE, FLASH_SECONDS)


## A row to pick: the rule's id, its text (wrapped, never cut) and its tier.
func _rule_row(rule: Rule) -> PanelContainer:
	var row: PanelContainer = PanelContainer.new()
	row.name = rule.id
	row.custom_minimum_size.y = ROW_HEIGHT
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.gui_input.connect(_on_row_input.bind(rule.id))
	row.mouse_entered.connect(_set_hovered.bind(rule.id))
	row.mouse_exited.connect(_set_hovered.bind(""))
	var line: HBoxContainer = HBoxContainer.new()
	line.name = "Line"
	line.add_theme_constant_override("separation", 14)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	var id_label: Label = _label(rule.id, RulesPanel.ID_COLOUR)
	id_label.custom_minimum_size.x = 44
	line.add_child(id_label)
	var text_label: Label = _label(rule.text, Color.WHITE)
	text_label.name = "Text"
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_child(text_label)
	line.add_child(TierBadge.badge(rule.tier))
	return row


func _on_row_input(event: InputEvent, rule_id: String) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
		_toggle(rule_id)


func _set_hovered(rule_id: String) -> void:
	_hovered_rule_id = rule_id
	for row: PanelContainer in _rule_list.get_children():
		_style_row(row)


## Picked rows are gold, like a chosen rule on the match setup screen.
func _style_row(row: PanelContainer) -> void:
	var picked: bool = _draft.has(row.name)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = RulesPanel.TRUE_ROW_COLOUR if picked else RulesPanel.ROW_COLOUR
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.set_border_width_all(2)
	if picked:
		style.border_color = RulesPanel.TRUE_BORDER_COLOUR
	elif row.name == _hovered_rule_id:
		style.border_color = RulesPanel.ROW_COLOUR.lightened(0.35)
	else:
		style.border_color = RulesPanel.ROW_COLOUR
	row.add_theme_stylebox_override("panel", style)


## A filter chip: All, or one tier in its colour.
func _chip(tier: String) -> Button:
	var chip: Button = Button.new()
	chip.name = "All" if tier == ALL_TIERS else TierBadge.title(tier)
	chip.text = chip.name
	chip.toggle_mode = true
	chip.button_group = _chip_group
	chip.button_pressed = tier == ALL_TIERS
	chip.focus_mode = Control.FOCUS_NONE
	chip.custom_minimum_size = Vector2(CHIP_WIDTH, CHIP_HEIGHT)
	chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	chip.add_theme_font_size_override("font_size", 16)
	var colour: Color = RulesPanel.ID_COLOUR if tier == ALL_TIERS else TierBadge.colour(tier)
	chip.add_theme_stylebox_override("normal", _chip_style(colour, false))
	chip.add_theme_stylebox_override("hover", _chip_style(colour.lightened(0.2), false))
	chip.add_theme_stylebox_override("pressed", _chip_style(colour, true))
	chip.add_theme_stylebox_override("hover_pressed", _chip_style(colour, true))
	chip.add_theme_color_override("font_color", colour)
	chip.add_theme_color_override("font_hover_color", colour.lightened(0.2))
	chip.add_theme_color_override("font_pressed_color", Color.WHITE)
	chip.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	chip.pressed.connect(_show_tier.bind(tier))
	return chip


func _chip_style(colour: Color, on: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = colour.darkened(0.55) if on else RulesPanel.ROW_COLOUR
	style.border_color = colour
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.content_margin_left = CHIP_MARGIN
	style.content_margin_right = CHIP_MARGIN
	return style


func _label(text: String, colour: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_FILL
	label.add_theme_color_override("font_color", colour)
	label.add_theme_font_size_override("font_size", 18)
	return label


## Larger text: labels and buttons scale; the name field by hand.
func _apply_text_scale() -> void:
	TextScale.apply(self, Settings.text_scale())
	_name_field.add_theme_font_size_override("font_size", roundi(NAME_FONT_SIZE * Settings.text_scale()))
