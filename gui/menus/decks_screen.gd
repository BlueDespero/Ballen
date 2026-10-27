class_name DecksScreen
extends Control

## The Decks screen, opened by the main menu's Decks button: every deck with
## its 5 rule ids and tier dots. A saved deck can be edited, renamed or deleted
## (after a confirm); the built-in Starter can only be copied. New deck and
## Edit open the deck editor over this screen. Back (or Escape) returns to the
## main menu.

const MAIN_MENU_SCENE: String = "res://main.tscn"
const EDITOR_SCENE: PackedScene = preload("res://gui/menus/deck_editor.tscn")
const ROW_HEIGHT: float = 56.0
const NAME_WIDTH: float = 240.0
const ROW_BUTTON_WIDTH: float = 96.0
const NAME_FIELD_FONT_SIZE: int = 20
const DELETE_COLOUR: Color = Color(0.92, 0.36, 0.32)
## Each row keeps the name of its deck here; rows are named Row0 (Starter),
## Row1, ... in list order, as deck names needn't make distinct node names.
const DECK_NAME_META: StringName = &"deck_name"

## Where the decks are saved; tests set their own before the screen is added.
var store_path: String = DeckStore.DEFAULT_PATH

@onready var _deck_list: VBoxContainer = %DeckList
@onready var _dialog: Control = %Dialog
@onready var _dialog_title: Label = %DialogTitle
@onready var _dialog_message: Label = %DialogMessage
@onready var _dialog_name: LineEdit = %DialogName
@onready var _dialog_hint: Label = %DialogHint
@onready var _dialog_confirm: Button = %DialogConfirm

var _book: RuleBook
var _store: DeckStore
var _editor: DeckEditor = null
## The deck the open dialog renames or deletes.
var _dialog_deck: String = ""
var _dialog_renames: bool = false
## The dialog's confirm button: gold for Rename (as in the scene), red for Delete.
var _rename_style: StyleBox
var _delete_style: StyleBoxFlat


func _ready() -> void:
	_book = RuleBook.load_default()
	_store = DeckStore.new(_book, store_path)
	%Back.pressed.connect(_on_back_pressed)
	%NewDeck.pressed.connect(func() -> void: _open_editor(DeckDraft.new(), "New deck"))
	%DialogCancel.pressed.connect(_close_dialog)
	_dialog_confirm.pressed.connect(_on_dialog_confirmed)
	_rename_style = _dialog_confirm.get_theme_stylebox("normal")
	_delete_style = _rename_style.duplicate() as StyleBoxFlat
	_delete_style.bg_color = DELETE_COLOUR.darkened(0.6)
	_delete_style.border_color = DELETE_COLOUR
	_dialog_name.text_changed.connect(_on_dialog_name_changed)
	_dialog_name.text_submitted.connect(func(_text: String) -> void: _on_dialog_confirmed())
	for tier: String in Rule.TIERS:
		var item: HBoxContainer = HBoxContainer.new()
		item.name = TierBadge.title(tier)
		item.add_theme_constant_override("separation", 6)
		item.add_child(TierBadge.dot(tier))
		item.add_child(_label(TierBadge.title(tier), TierBadge.colour(tier), 15))
		%Legend.add_child(item)
	Settings.changed.connect(_apply_text_scale)
	_fill()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or _editor != null:
		return
	get_viewport().set_input_as_handled()
	if _dialog.visible:
		_close_dialog()
	else:
		_on_back_pressed()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


## One row per deck, Starter first. Old rows are freed at once, so new ones
## keep their names (this never runs from a row's own button).
func _fill() -> void:
	for child: Node in _deck_list.get_children():
		child.free()
	for deck_name: String in _store.names():
		var row: PanelContainer = _deck_row(deck_name)
		row.name = "Row%d" % _deck_list.get_child_count()
		_deck_list.add_child(row)
	_apply_text_scale()


func _deck_row(deck_name: String) -> PanelContainer:
	var row: PanelContainer = PanelContainer.new()
	row.set_meta(DECK_NAME_META, deck_name)
	row.custom_minimum_size.y = ROW_HEIGHT
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = RulesPanel.ROW_COLOUR
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	row.add_theme_stylebox_override("panel", style)
	var line: HBoxContainer = HBoxContainer.new()
	line.name = "Line"
	line.add_theme_constant_override("separation", 10)
	row.add_child(line)
	var name_label: Label = _label(deck_name, Color.WHITE, 20)
	name_label.name = "DeckName"
	name_label.custom_minimum_size.x = NAME_WIDTH
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.add_child(name_label)
	var rules: HBoxContainer = HBoxContainer.new()
	rules.name = "Rules"
	rules.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rules.add_theme_constant_override("separation", 6)
	line.add_child(rules)
	for rule: Rule in _store.deck(deck_name).rules:
		rules.add_child(TierBadge.dot(rule.tier))
		var id_label: Label = _label(rule.id, RulesPanel.ID_COLOUR, 17)
		id_label.custom_minimum_size.x = 40
		rules.add_child(id_label)
	if _store.is_read_only(deck_name):
		line.add_child(_label("Built in", RulesPanel.HINT_COLOUR, 15))
		line.add_child(_row_button("Copy", _copy.bind(deck_name)))
	else:
		line.add_child(_row_button("Edit", _edit.bind(deck_name)))
		line.add_child(_row_button("Rename", _ask_rename.bind(deck_name)))
		line.add_child(_row_button("Delete", _ask_delete.bind(deck_name), DELETE_COLOUR))
	return row


func _copy(deck_name: String) -> void:
	_open_editor(DeckDraft.copy_of(_store, deck_name), "New deck")


func _edit(deck_name: String) -> void:
	_open_editor(DeckDraft.editing(_store, deck_name), "Edit deck")


## The editor covers this screen until it closes.
func _open_editor(draft: DeckDraft, title: String) -> void:
	_editor = EDITOR_SCENE.instantiate()
	add_child(_editor)
	_editor.open(draft, _store, _book, title)
	_editor.closed.connect(_on_editor_closed)


func _on_editor_closed(_saved: bool) -> void:
	remove_child(_editor)
	_editor.queue_free()
	_editor = null
	_fill()


func _ask_rename(deck_name: String) -> void:
	_open_dialog(deck_name, true, "Rename deck", "")
	_dialog_name.text = deck_name
	_dialog_name.grab_focus()
	_dialog_name.select_all()
	_on_dialog_name_changed(deck_name)


func _ask_delete(deck_name: String) -> void:
	_open_dialog(deck_name, false, "Delete deck?", "Delete \"%s\"? This can't be undone." % deck_name)


func _open_dialog(deck_name: String, renames: bool, title: String, message: String) -> void:
	_dialog_deck = deck_name
	_dialog_renames = renames
	_dialog_title.text = title
	_dialog_message.text = message
	_dialog_message.visible = message != ""
	_dialog_name.visible = renames
	_dialog_hint.visible = renames
	_dialog_hint.text = ""
	_dialog_confirm.text = "Rename" if renames else "Delete"
	_dialog_confirm.disabled = false
	for state: String in ["normal", "hover", "pressed"]:
		_dialog_confirm.add_theme_stylebox_override(state, _rename_style if renames else _delete_style)
	_dialog.visible = true


func _on_dialog_name_changed(text: String) -> void:
	var problem: String = _store.name_problem(text, _dialog_deck)
	_dialog_hint.text = problem
	_dialog_confirm.disabled = problem != ""


func _on_dialog_confirmed() -> void:
	if _dialog_confirm.disabled:
		return
	var done: bool
	if _dialog_renames:
		done = _store.rename(_dialog_deck, _dialog_name.text.strip_edges())
	else:
		done = _store.delete(_dialog_deck)
	if done:
		_close_dialog()
		_fill()


func _close_dialog() -> void:
	_dialog.visible = false
	_dialog_name.release_focus()


func _row_button(text: String, on_pressed: Callable, colour: Color = Color.WHITE) -> Button:
	var button: Button = Button.new()
	button.name = text
	button.text = text
	button.custom_minimum_size = Vector2(ROW_BUTTON_WIDTH, 40)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", colour)
	button.add_theme_color_override("font_hover_color", colour)
	button.add_theme_stylebox_override("normal", _button_style(RulesPanel.ROW_COLOUR.lightened(0.08), 0.0))
	button.add_theme_stylebox_override("hover", _button_style(RulesPanel.ROW_COLOUR.lightened(0.18), 0.5))
	button.add_theme_stylebox_override("pressed", _button_style(RulesPanel.ROW_COLOUR.lightened(0.18), 0.5))
	button.pressed.connect(on_pressed)
	return button


func _button_style(colour: Color, border_light: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = colour
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = colour.lightened(border_light)
	return style


func _label(text: String, colour: Color, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_FILL
	label.add_theme_color_override("font_color", colour)
	label.add_theme_font_size_override("font_size", font_size)
	return label


## Larger text: labels and buttons scale; the rename field by hand.
func _apply_text_scale() -> void:
	TextScale.apply(self, Settings.text_scale())
	_dialog_name.add_theme_font_size_override("font_size", roundi(NAME_FIELD_FONT_SIZE * Settings.text_scale()))
