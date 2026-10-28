class_name RulesPanel
extends PanelContainer

## The rules panel on the right: the AI's 5 rules on top, the player's 5 below
## with their true rule highlighted, and each side's skip pips beside its
## title. The player selects one of the AI's rules by clicking it and names it
## by holding Guess under them (or tapping it, then Confirm, with the "guess
## without holding" setting). Two small buttons, ✗ and ?, at the right end of
## each AI rule keep the player's private note mark on it. On a full board,
## holding Seal beside Guess makes the player's sealed forced guess instead.

## The player held Guess to the end with one of the AI's rules selected.
signal guess_requested(rule_id: String)
## The player held Seal to the end with one of the AI's rules selected.
signal seal_requested(rule_id: String)

const ROW_HEIGHT: float = 44.0
const PIP_SIZE: float = 16.0
const PIP_EMPTY_COLOUR: Color = Color(0.6, 0.64, 0.7)
const CROSS_TEXT_ALPHA: float = 0.45
## How far down a line of text a ✗ rule's strike runs (0 top, 1 bottom).
const STRIKE_HEIGHT: float = 0.55
## A rule too long for one line of its row (measured against the room the
## row leaves its text, at the text size in use) is shown one font step
## smaller (Larger text scales it from there), so its two lines fit a row's
## height.
const LONG_RULE_FONT_SIZE: int = 14
## Larger text: more rules wrap (and so drop the step), and rows and
## sections sit closer, so the panel still fits 720 px with long rules in
## both decks.
const LARGER_ROW_HEIGHT: float = 40.0
const ROW_SEPARATION: int = 4
const LARGER_ROW_SEPARATION: int = 2
const SECTION_SEPARATION: int = 8
const LARGER_SECTION_SEPARATION: int = 4
## Between the two lines of a wrapped rule with Larger text (the font's own
## spacing is generous; this leaves lines about 1.1 times the text size).
const LARGER_LINE_SPACING: int = -5
## The yellow left edge of a rule marked ?.
const SUSPECT_EDGE_WIDTH: int = 4

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

## Guess and Seal fire on a tap and a Confirm tap instead of a hold.
var guess_without_holding: bool = false:
	set(value):
		guess_without_holding = value
		if is_node_ready():
			_guess_button.tap_to_confirm = value
			_seal_button.tap_to_confirm = value
		_update_guess()

## Larger text: the panel's text is this many times its built size. Rows are
## built for the scale set when the decks are shown.
var text_scale: float = 1.0:
	set(value):
		text_scale = value
		TextScale.apply(self, value)
		_apply_spacing()

## The id of the AI's rule the player selected; "" for none.
var selected_rule_id: String = ""

## The player's note mark (`NoteMark.Mark`) on each of the AI's rules, by rule
## id. Private notes the game never reads; new decks (a rematch) start unmarked.
var marks: Dictionary[String, int]:
	get = _get_marks

var _match_over: bool = false
var _marks: Dictionary[String, int] = {}
## The AI's true rule once the match is over; "" before.
var _ai_true_rule_id: String = ""

@onready var _sections: VBoxContainer = $Sections
@onready var _ai_rules: VBoxContainer = %AIRules
@onready var _player_rules: VBoxContainer = %PlayerRules
@onready var _guess_button: GuessButton = %GuessButton
@onready var _seal_button: GuessButton = %SealButton
@onready var _guess_hint: Label = %GuessHint
@onready var _mark_hint: Label = %MarkHint
@onready var _ai_skip_pips: HBoxContainer = %AISkipPips
@onready var _player_skip_pips: HBoxContainer = %PlayerSkipPips


func _ready() -> void:
	_guess_button.guessed.connect(_on_guessed)
	_seal_button.guessed.connect(_on_sealed)
	_guess_hint.add_theme_color_override("font_color", Palette.HINT_COLOUR)
	_mark_hint.add_theme_color_override("font_color", Palette.HINT_COLOUR)
	_apply_spacing()
	_update_guess()


func _larger_text() -> bool:
	return text_scale > 1.0


## Larger text sets the sections and the rule rows closer together.
func _apply_spacing() -> void:
	if not is_node_ready():
		return
	var larger: bool = _larger_text()
	_sections.add_theme_constant_override("separation", LARGER_SECTION_SEPARATION if larger else SECTION_SEPARATION)
	for list: VBoxContainer in [_ai_rules, _player_rules]:
		list.add_theme_constant_override("separation", LARGER_ROW_SEPARATION if larger else ROW_SEPARATION)


## Shows both decks for a new match (also a rematch: the match-over marks go).
func show_decks(ai_deck: Deck, player_deck: Deck, player_true_rule: Rule) -> void:
	_match_over = false
	_ai_true_rule_id = ""
	_fill(_ai_rules, ai_deck, null)
	_fill(_player_rules, player_deck, player_true_rule)
	_marks.clear()
	for row: Node in _ai_rules.get_children():
		var panel: PanelContainer = row as PanelContainer
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		panel.gui_input.connect(_on_ai_row_input.bind(String(panel.name)))
		_marks[String(panel.name)] = NoteMark.Mark.NONE
		_add_mark_buttons(panel)
	# Explains the mark buttons until the player first uses one.
	_mark_hint.visible = not Settings.note_marks_seen
	_select("")
	TextScale.apply(self, text_scale)
	for list: VBoxContainer in [_ai_rules, _player_rules]:
		for row: Node in list.get_children():
			_fit_rule_text(row as PanelContainer)


## Drops a rule's text one font step (LONG_RULE_FONT_SIZE, scaled) when it is
## wider than the room its row leaves it: the panel's width less the row's
## margins and the rule id, TRUE label and mark buttons beside it. Called once
## the row is complete and scaled; a dropped rule stays dropped.
func _fit_rule_text(row: PanelContainer) -> void:
	var line: HBoxContainer = row.get_node("Line")
	var text_label: Label = line.get_node("Text")
	var built_size: int = text_label.get_meta(TextScale.BASE_SIZE_META, text_label.get_theme_font_size("font_size"))
	if built_size <= LONG_RULE_FONT_SIZE:
		return
	var room: float = size.x - get_theme_stylebox("panel").get_minimum_size().x
	room -= row.get_theme_stylebox("panel").get_minimum_size().x
	for child: Node in line.get_children():
		if child != text_label:
			room -= (child as Control).get_combined_minimum_size().x
	room -= line.get_theme_constant("separation") * (line.get_child_count() - 1)
	var font: Font = text_label.get_theme_font("font")
	var text_width: float = font.get_string_size(text_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_label.get_theme_font_size("font_size")).x
	if text_width > room:
		text_label.set_meta(TextScale.BASE_SIZE_META, LONG_RULE_FONT_SIZE)
		text_label.add_theme_font_size_override("font_size", roundi(LONG_RULE_FONT_SIZE * text_scale))


## The ✗ and ? note mark buttons at the right end of an AI rule row. They take
## their own taps, so tapping them never selects the row; the row starts
## unmarked.
func _add_mark_buttons(row: PanelContainer) -> void:
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.name = "Marks"
	buttons.add_theme_constant_override("separation", 2)
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.get_node("Line").add_child(buttons)
	for mark: NoteMark.Mark in [NoteMark.Mark.CROSS, NoteMark.Mark.QUESTION]:
		var button: NoteMarkButton = NoteMarkButton.new(mark)
		button.name = "Cross" if mark == NoteMark.Mark.CROSS else "Question"
		button.pressed.connect(_on_mark_pressed.bind(String(row.name), mark))
		buttons.add_child(button)
	var text_label: Label = row.get_node("Line/Text") as Label
	text_label.draw.connect(_strike_through.bind(text_label, String(row.name)))
	row.draw.connect(_draw_suspect_edge.bind(row))


## A press sets, switches or clears the row's mark. A rule marked ✗ fades and
## is struck through, so the rules the player still considers stand out; one
## marked ? gets a yellow left edge.
func _on_mark_pressed(rule_id: String, pressed: NoteMark.Mark) -> void:
	var mark: NoteMark.Mark = NoteMark.toggled(_marks[rule_id] as NoteMark.Mark, pressed)
	_marks[rule_id] = mark
	var row: Node = _ai_rules.get_node(rule_id)
	(row.get_node("Line/Marks/Cross") as NoteMarkButton).lit = mark == NoteMark.Mark.CROSS
	(row.get_node("Line/Marks/Question") as NoteMarkButton).lit = mark == NoteMark.Mark.QUESTION
	var text_label: Label = row.get_node("Line/Text") as Label
	text_label.modulate.a = CROSS_TEXT_ALPHA if mark == NoteMark.Mark.CROSS else 1.0
	text_label.queue_redraw()
	_style_ai_row(row as PanelContainer)
	Settings.mark_note_marks_seen()
	_mark_hint.hide()


## Over a ✗ rule's text: a line through the middle of each line of text, as
## wide as its letters (measured from the label, so it follows larger text).
func _strike_through(text_label: Label, rule_id: String) -> void:
	if _marks.get(rule_id, NoteMark.Mark.NONE) != NoteMark.Mark.CROSS:
		return
	# Each line of text by its top: [left, right, bottom].
	var lines: Dictionary[float, Vector3] = {}
	for i: int in text_label.text.length():
		var bounds: Rect2 = text_label.get_character_bounds(i)
		if bounds.size.x <= 0.0 or text_label.text[i] == " ":
			continue
		var top: float = bounds.position.y
		var line: Vector3 = lines.get(top, Vector3(bounds.position.x, bounds.end.x, bounds.end.y))
		lines[top] = Vector3(minf(line.x, bounds.position.x), maxf(line.y, bounds.end.x), line.z)
	var font_size: int = text_label.get_theme_font_size("font_size")
	var width: float = maxf(1.0, font_size / 10.0)
	for top: float in lines:
		var line: Vector3 = lines[top]
		var y: float = top + (line.z - top) * STRIKE_HEIGHT
		text_label.draw_line(Vector2(line.x, y), Vector2(line.y, y), Color.WHITE, width, true)


func _get_marks() -> Dictionary[String, int]:
	return _marks.duplicate()


## Once the match is over: marks the AI's true rule and closes guessing.
func show_match_over(ai_true_rule: Rule) -> void:
	if _match_over:
		return
	_match_over = true
	_ai_true_rule_id = ai_true_rule.id
	guess_enabled = false
	seal_enabled = false
	_select("")
	for row: Node in _ai_rules.get_children():
		var panel: PanelContainer = row as PanelContainer
		panel.mouse_default_cursor_shape = Control.CURSOR_ARROW
		if String(panel.name) == ai_true_rule.id:
			# Right after the text, before the mark buttons.
			var true_label: Label = Palette.label("TRUE", Palette.GOLD_COLOUR)
			panel.get_node("Line").add_child(true_label)
			panel.get_node("Line").move_child(true_label, panel.get_node("Line/Text").get_index() + 1)
	_update_guess()
	TextScale.apply(self, text_scale)
	_fit_rule_text(_ai_rules.get_node(ai_true_rule.id) as PanelContainer)


## Clicking an AI rule selects it; clicking it again clears the selection.
func _on_ai_row_input(event: InputEvent, rule_id: String) -> void:
	if _match_over:
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
		_select("" if rule_id == selected_rule_id else rule_id)


func _select(rule_id: String) -> void:
	selected_rule_id = rule_id
	# An armed Confirm was for the rule selected before.
	_guess_button.cancel()
	_seal_button.cancel()
	for row: Node in _ai_rules.get_children():
		_style_ai_row(row as PanelContainer)
	_update_guess()


## An AI rule row's look: selected, marked ?, or the AI's true rule once the
## match is over.
func _style_ai_row(row: PanelContainer) -> void:
	var rule_id: String = String(row.name)
	row.add_theme_stylebox_override("panel", _style(rule_id == selected_rule_id, rule_id == _ai_true_rule_id))
	row.queue_redraw()


## Over a rule marked ?: a yellow left edge, drawn on top of the row's box so
## a selected or true row keeps its own border.
func _draw_suspect_edge(row: PanelContainer) -> void:
	if _marks.get(String(row.name), NoteMark.Mark.NONE) != NoteMark.Mark.QUESTION:
		return
	var edge: StyleBoxFlat = StyleBoxFlat.new()
	edge.draw_center = false
	edge.set_corner_radius_all(8)
	edge.border_width_left = SUSPECT_EDGE_WIDTH
	edge.border_color = Palette.GOLD_COLOUR
	row.draw_style_box(edge, Rect2(Vector2.ZERO, row.size))


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
		_guess_hint.text = "%s to name %s now (right wins, wrong loses), or Seal for your forced guess." % [_how("Guess"), selected_rule_id]
	elif seal_enabled:
		_guess_hint.text = "%s to seal %s as your forced guess. One right guess wins; else a draw." % [_how("Seal"), selected_rule_id]
	else:
		_guess_hint.text = "%s to name %s. Right wins, wrong loses." % [_how("Guess"), selected_rule_id]


## How to pull a trigger, for the hint: "Hold Guess", or "Tap Guess, then
## Confirm," without holding.
func _how(trigger: String) -> String:
	return "Tap %s, then Confirm," % trigger if guess_without_holding else "Hold %s" % trigger


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
	style.border_color = Palette.RED_COLOUR if filled else PIP_EMPTY_COLOUR
	style.bg_color = Palette.RED_COLOUR if filled else Color.TRANSPARENT
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
	row.custom_minimum_size.y = LARGER_ROW_HEIGHT if _larger_text() else ROW_HEIGHT
	row.add_theme_stylebox_override("panel", _style(false, is_true))
	var line: HBoxContainer = HBoxContainer.new()
	line.name = "Line"
	line.add_theme_constant_override("separation", 12)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	var id_label: Label = Palette.label(rule.id, Palette.ID_COLOUR)
	id_label.custom_minimum_size.x = 40
	line.add_child(id_label)
	var text_label: Label = Palette.label(rule.text, Color.WHITE)
	text_label.name = "Text"
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# A long rule takes two lines rather than losing its end, in smaller text
	# (see _fit_rule_text) so the row keeps its height and the panel fits the
	# screen.
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _larger_text():
		text_label.add_theme_constant_override("line_spacing", LARGER_LINE_SPACING)
	line.add_child(text_label)
	if is_true:
		line.add_child(Palette.label("TRUE", Palette.GOLD_COLOUR))
	return row


## A rule row's box. Selected rows turn blue and the true rule gold.
func _style(is_selected: bool, is_true: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.ROW_COLOUR
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	if is_true or is_selected:
		style.bg_color = Palette.TRUE_ROW_COLOUR if is_true else Palette.SELECTED_ROW_COLOUR
		style.set_border_width_all(2)
		style.border_color = Palette.GOLD_COLOUR if is_true else Palette.SELECTED_BORDER_COLOUR
	return style
