class_name NoteMarkButton
extends Button

## The small button on the left of one of the AI's rule rows: each tap cycles
## the rule's note mark, none -> ✗ ruled out -> ? suspect -> none. It draws its
## own glyphs, so they show whatever the font. Works with mouse and touch.

## The player tapped the button and the mark moved on.
signal mark_changed(mark: NoteMark.Mark)

const HIT_SIZE: float = 36.0
const RING_RADIUS: float = 12.0
const RING_WIDTH: float = 2.0
const CROSS_HALF: float = 5.0
const EMPTY_COLOUR: Color = Color(0.6, 0.64, 0.7, 0.6)
const HOVER_COLOUR: Color = Color(0.85, 0.88, 0.92)
const RULED_OUT_COLOUR: Color = Color(0.92, 0.36, 0.32)
const SUSPECT_COLOUR: Color = Color(1.0, 0.82, 0.3)

var mark: NoteMark.Mark = NoteMark.Mark.NONE:
	set(value):
		mark = value
		tooltip_text = _tooltip()
		queue_redraw()


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(HIT_SIZE, HIT_SIZE)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = _tooltip()
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	mark = NoteMark.next(mark)
	mark_changed.emit(mark)


func _draw() -> void:
	var centre: Vector2 = size / 2.0
	var colour: Color = _colour()
	draw_arc(centre, RING_RADIUS, 0.0, TAU, 32, colour, RING_WIDTH, true)
	match mark:
		NoteMark.Mark.RULED_OUT:
			var a: Vector2 = Vector2(CROSS_HALF, CROSS_HALF)
			var b: Vector2 = Vector2(CROSS_HALF, -CROSS_HALF)
			draw_line(centre - a, centre + a, colour, RING_WIDTH + 0.5, true)
			draw_line(centre - b, centre + b, colour, RING_WIDTH + 0.5, true)
		NoteMark.Mark.SUSPECT:
			var font: Font = get_theme_default_font()
			var font_size: int = get_theme_default_font_size()
			var baseline: float = centre.y + (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0
			draw_string(font, Vector2(0.0, baseline), "?", HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, colour)


func _colour() -> Color:
	match mark:
		NoteMark.Mark.RULED_OUT:
			return RULED_OUT_COLOUR
		NoteMark.Mark.SUSPECT:
			return SUSPECT_COLOUR
		_:
			return HOVER_COLOUR if is_hovered() else EMPTY_COLOUR


func _tooltip() -> String:
	match mark:
		NoteMark.Mark.RULED_OUT:
			return "Ruled out (your note). Tap for suspect."
		NoteMark.Mark.SUSPECT:
			return "Suspect (your note). Tap to clear."
		_:
			return "Tap to mark this rule ruled out."
