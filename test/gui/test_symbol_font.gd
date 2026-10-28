extends GutTest

# The web build has no system fonts to fall back on, so the default font
# carries a bundled symbol font for the rule texts' arrows.

const RIGHT_ARROW: int = 0x2192
const LEFT_ARROW: int = 0x2190


func test_the_default_font_covers_the_arrows() -> void:
	assert_true(ThemeDB.fallback_font.has_char(RIGHT_ARROW), "→")
	assert_true(ThemeDB.fallback_font.has_char(LEFT_ARROW), "←")


## A fallback's line metrics count for every line, symbols or not.
func test_the_symbol_font_makes_no_line_taller() -> void:
	var plain: FontFile = ThemeDB.fallback_font.duplicate()
	plain.fallbacks = []
	for font_size: int in [14, 16, 20, 32, 40]:
		assert_eq(ThemeDB.fallback_font.get_height(font_size), plain.get_height(font_size), "size %d" % font_size)


func test_a_label_made_in_code_gets_the_arrows() -> void:
	var label: Label = Label.new()
	add_child_autofree(label)
	assert_true(label.get_theme_font("font").has_char(RIGHT_ARROW))
