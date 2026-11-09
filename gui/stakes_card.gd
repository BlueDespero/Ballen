class_name StakesCard
extends PanelContainer

## The card that confirms a guess (or a sealed forced guess) after a tap on
## Guess or Seal. A guess can't be undone and ends the match, so the card says
## what is at stake in plain words, and what the player's own note marks say,
## rather than asking "are you sure?". Its safe button (Keep playing, or Not
## yet) sits on the right, where Guess was, so a quick second tap keeps
## playing; the button that guesses sits on the left. It reads only the
## player's notes, never the match, so it gives nothing away.

## The player confirmed: name the rule.
signal confirmed
## The player backed out.
signal cancelled

const WIDTH: float = 488.0
const BUTTON_HEIGHT: float = 48.0
const CONTENT_MARGIN: float = 16.0
const GUESS_FILL: Color = Color(0.62, 0.16, 0.18)
const GUESS_BORDER: Color = Color(0.93, 0.4, 0.4)
const KEEP_FILL: Color = Color(0.2, 0.23, 0.28)
const KEEP_BORDER: Color = Color(0.42, 0.47, 0.55)

## Whether the card confirms a sealed forced guess rather than a guess.
var sealing: bool = false

var _title: Label
var _rule_text: Label
var _stakes: Label
var _notes: Label
var _confirm: Button
var _cancel: Button


func _init() -> void:
	name = "StakesCard"
	visible = false
	custom_minimum_size.x = WIDTH
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.105, 0.118, 0.141)
	style.border_color = GUESS_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(CONTENT_MARGIN)
	add_theme_stylebox_override("panel", style)
	var lines: VBoxContainer = VBoxContainer.new()
	lines.add_theme_constant_override("separation", 8)
	add_child(lines)
	_title = Palette.label("", Color.WHITE, 22)
	_title.name = "Title"
	_rule_text = Palette.label("", Palette.HINT_COLOUR, 17)
	_rule_text.name = "RuleText"
	_rule_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stakes = Palette.label("", Color.WHITE, 18)
	_stakes.name = "Stakes"
	_stakes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notes = Palette.label("", Palette.GOLD_COLOUR, 16)
	_notes.name = "Notes"
	_notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for label: Label in [_title, _rule_text, _stakes, _notes]:
		# A wrapping label measures its height at its width, so give it one
		# before the card is first laid out.
		label.custom_minimum_size.x = WIDTH - CONTENT_MARGIN * 2.0
		lines.add_child(label)
	# The buttons sit at the bottom, level with the Guess button the card covers.
	var push_down: Control = Control.new()
	push_down.size_flags_vertical = Control.SIZE_EXPAND_FILL
	push_down.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(push_down)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	lines.add_child(buttons)
	_confirm = _button("Confirm", GUESS_FILL, GUESS_BORDER)
	_confirm.pressed.connect(_on_confirm)
	buttons.add_child(_confirm)
	var gap: Control = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.add_child(gap)
	_cancel = _button("Cancel", KEEP_FILL, KEEP_BORDER)
	_cancel.pressed.connect(_on_cancel)
	buttons.add_child(_cancel)


## Opens the card for rule. still_possible counts the opponent's rules the
## player has not marked ✗; ruled_out says whether they marked this one.
func open(rule: Rule, is_sealing: bool, still_possible: int, ruled_out: bool) -> void:
	sealing = is_sealing
	_title.text = tr("Seal %s as your forced guess?") % rule.id if sealing else tr("Guess %s?") % rule.id
	_rule_text.text = "\"%s\"" % tr(rule.text)
	_stakes.text = tr("One right guess wins. Both right or both wrong: a draw.") if sealing \
		else tr("Right: you win. Wrong: you lose.")
	if ruled_out:
		_notes.text = tr("Your notes say you ruled this one out.")
	elif still_possible == Deck.SIZE:
		_notes.text = tr("Your notes don't rule out any of its rules yet.")
	elif still_possible == 1:
		_notes.text = tr("By your notes, it is the only rule left.")
	else:
		_notes.text = tr("By your notes, %d of 5 rules are still possible.") % still_possible
	_confirm.text = tr("Seal %s") % rule.id if sealing else tr("Guess %s") % rule.id
	_cancel.text = tr("Not yet") if sealing else tr("Keep playing")
	visible = true


func close() -> void:
	visible = false


func _on_confirm() -> void:
	close()
	confirmed.emit()


func _on_cancel() -> void:
	close()
	cancelled.emit()


func _button(text: String, fill: Color, border: Color) -> Button:
	var button: Button = Button.new()
	button.name = text
	button.text = text
	button.custom_minimum_size = Vector2(170, BUTTON_HEIGHT)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 18)
	for state: String in ["normal", "hover", "pressed"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = fill.lightened(0.1) if state != "normal" else fill
		style.border_color = border
		style.set_border_width_all(2)
		style.set_corner_radius_all(10)
		style.content_margin_left = 16
		style.content_margin_right = 16
		button.add_theme_stylebox_override(state, style)
	return button
