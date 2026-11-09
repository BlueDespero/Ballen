class_name CoachMark
extends PanelContainer

## A one-time hint for a new player, in a small gold-edged card beside the
## control it explains. It shows only while the player could do what it says,
## and goes for good once they do (Settings.mark_hint_seen): no Next button, so
## it can't be clicked past unread. hint_for() picks the hint for a view, so
## the scene only places it.

const WIDTH: float = 264.0
const FONT_SIZE: int = 15

var _label: Label


func _init() -> void:
	name = "CoachMark"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.17, 0.15, 0.08)
	style.border_color = BoardView.GLOW_COLOUR
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)
	_label = Palette.label("", Color.WHITE, FONT_SIZE)
	_label.name = "Text"
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size.x = WIDTH - 20.0
	add_child(_label)


## The hint to show for this view, or "" for none: picking the AI's colour
## while the player has never picked one; reading the AI's placements while it
## is the player's turn to place, the AI has placed, and the player has never
## used a note mark (in their first match only).
static func hint_for(view: PublicView, settings: GameSettings) -> String:
	if view.phase == Match.Phase.OVER:
		return ""
	if view.colour_pick_due() and not settings.hint_seen(GameSettings.HINT_COLOUR_PICK):
		return GameSettings.HINT_COLOUR_PICK
	var placing: bool = view.current_player == view.viewer and view.phase == Match.Phase.PLACE
	if placing and _opponent_has_placed(view) and not settings.note_marks_seen \
			and not settings.hint_seen(GameSettings.HINT_WATCH_AI):
		return GameSettings.HINT_WATCH_AI
	return ""


## What a hint says.
static func text_for(hint: String) -> String:
	match hint:
		GameSettings.HINT_COLOUR_PICK:
			return "You pick the colour the AI places next. Pick one that some of its rules can't allow: where it goes, or a skip, gives its rule away."
		GameSettings.HINT_WATCH_AI:
			return "Watch where the AI places: which of its rules allow that cell? Tap the cross beside those that don't."
	return ""


## Shows the hint's text with its bottom-right corner at corner (in its
## parent's coordinates); "" hides it.
func show_hint(hint: String, corner: Vector2) -> void:
	visible = hint != ""
	if not visible:
		return
	_label.text = text_for(hint)
	reset_size()
	position = corner - size


static func _opponent_has_placed(view: PublicView) -> bool:
	for event: HistoryEntry in view.position.history:
		if event.type == HistoryEntry.Type.PLACEMENT and event.player != view.viewer:
			return true
	return false
