class_name Palette
extends RefCounted

## The colours the rules panel, the setup screen and the deck screens share,
## and the plain label they all build their rows from.

## A rule or deck row, and the true (or picked) one.
const ROW_COLOUR: Color = Color(0.17, 0.19, 0.23)
const TRUE_ROW_COLOUR: Color = Color(0.33, 0.27, 0.1)
## The true rule's border and TRUE label, and the ? note mark.
const GOLD_COLOUR: Color = Color(1.0, 0.82, 0.3)
const SELECTED_ROW_COLOUR: Color = Color(0.16, 0.24, 0.34)
const SELECTED_BORDER_COLOUR: Color = Color(0.45, 0.72, 1.0)
## Rule ids and other secondary text.
const ID_COLOUR: Color = Color(0.6, 0.64, 0.7)
const HINT_COLOUR: Color = Color(0.7, 0.74, 0.8)
## The ✗ note mark, skips taken and Delete.
const RED_COLOUR: Color = Color(0.92, 0.36, 0.32)


## A label of this text and colour, centred in the height it is given; font_size
## 0 keeps the theme's size.
static func label(text: String, colour: Color, font_size: int = 0) -> Label:
	var new_label: Label = Label.new()
	new_label.text = text
	new_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	new_label.size_flags_vertical = Control.SIZE_FILL
	new_label.add_theme_color_override("font_color", colour)
	if font_size > 0:
		new_label.add_theme_font_size_override("font_size", font_size)
	return new_label
