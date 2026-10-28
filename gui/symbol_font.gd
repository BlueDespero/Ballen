extends Node

## Symbol font (autoload `SymbolFont`): adds the bundled Noto Sans Symbols as a
## fallback of the default font, so every label and button, in scenes or made
## in code, can show the rule texts' arrows (← →). Desktop builds find them in
## the system fonts; the web build has no system fonts, so without this they
## show as boxes.

const FONT: FontFile = preload("res://assets/fonts/NotoSansSymbols-Variable.ttf")


func _init() -> void:
	var base: Font = ThemeDB.fallback_font
	if base.fallbacks.has(FONT):
		return
	var fallbacks: Array[Font] = base.fallbacks.duplicate()
	fallbacks.append(FONT)
	base.fallbacks = fallbacks
