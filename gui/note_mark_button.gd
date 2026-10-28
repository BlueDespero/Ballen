class_name NoteMarkButton
extends Button

## One of the two note mark buttons at the right end of one of the AI's rule
## rows: ✗ (rule out) or ? (suspect). A rounded square, dim when off, brighter
## under the pointer, filled red (✗) or yellow (?) while the row has its mark.
## It draws its own glyph, so it shows whatever the font. The rules panel
## decides the row's mark on a press (`NoteMark.toggled`) and sets `lit`.
## Works with mouse and touch: it takes taps in a 44 px square (TOUCH_SIZE)
## though it takes only 36 px of the row, so the rules panel still fits a
## 720 px screen. ✗ reaches out to its left, ? to its right, so the two
## buttons never share a point.

## The room the button takes in the row.
const HIT_SIZE: float = 36.0
## The square it takes taps and clicks in, a finger's width.
const TOUCH_SIZE: float = 44.0
const BOX_SIZE: float = 28.0
const CORNER_RADIUS: int = 6
const LINE_WIDTH: float = 2.0
const CROSS_HALF: float = 5.0
const OFF_COLOUR: Color = Color(0.6, 0.64, 0.7, 0.6)
const HOVER_COLOUR: Color = Color(0.85, 0.88, 0.92)
const HOVER_FILL: Color = Color(1.0, 1.0, 1.0, 0.08)
const CROSS_COLOUR: Color = Palette.RED_COLOUR
const QUESTION_COLOUR: Color = Palette.GOLD_COLOUR
## The glyph on a filled (lit) button.
const LIT_GLYPH_COLOUR: Color = Color(0.1, 0.11, 0.14)

## The mark this button sets: `NoteMark.Mark.CROSS` or `QUESTION`.
var mark: NoteMark.Mark = NoteMark.Mark.CROSS

## Whether the row has this button's mark.
var lit: bool = false:
	set(value):
		lit = value
		queue_redraw()


func _init(button_mark: NoteMark.Mark = NoteMark.Mark.CROSS) -> void:
	mark = button_mark
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(HIT_SIZE, HIT_SIZE)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Rule out (your note)" if mark == NoteMark.Mark.CROSS else "Suspect (your note)"


## Where the button takes taps, in its own coordinates: TOUCH_SIZE square,
## centred vertically, reaching out sideways away from the other mark button.
func touch_rect() -> Rect2:
	var extra: Vector2 = Vector2(TOUCH_SIZE, TOUCH_SIZE) - size
	var left: float = -extra.x if mark == NoteMark.Mark.CROSS else 0.0
	return Rect2(Vector2(left, -extra.y / 2.0), Vector2(TOUCH_SIZE, TOUCH_SIZE))


func _has_point(point: Vector2) -> bool:
	return touch_rect().has_point(point)


func _draw() -> void:
	var centre: Vector2 = size / 2.0
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.set_corner_radius_all(CORNER_RADIUS)
	box.set_border_width_all(int(LINE_WIDTH))
	box.anti_aliasing = true
	var glyph_colour: Color
	if lit:
		box.bg_color = _mark_colour()
		box.border_color = _mark_colour()
		glyph_colour = LIT_GLYPH_COLOUR
	else:
		var colour: Color = HOVER_COLOUR if is_hovered() else OFF_COLOUR
		box.bg_color = HOVER_FILL if is_hovered() else Color.TRANSPARENT
		box.border_color = colour
		glyph_colour = colour
	draw_style_box(box, Rect2(centre - Vector2(BOX_SIZE, BOX_SIZE) / 2.0, Vector2(BOX_SIZE, BOX_SIZE)))
	if mark == NoteMark.Mark.CROSS:
		Glyph.draw_cross(self, centre, CROSS_HALF, glyph_colour, LINE_WIDTH + 0.5)
	else:
		var font: Font = get_theme_font("font")
		var font_size: int = get_theme_font_size("font_size")
		var baseline: float = centre.y + (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0
		draw_string(font, Vector2(0.0, baseline), "?", HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, glyph_colour)


func _mark_colour() -> Color:
	return CROSS_COLOUR if mark == NoteMark.Mark.CROSS else QUESTION_COLOUR
