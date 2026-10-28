class_name Glyph
extends RefCounted

## Symbols the game draws as shapes instead of typing them: the web build has
## only the default font, which lacks ✗, ◀ and ▶, so typed ones show as boxes.


## A ✗ centred on centre, its arms reaching half out each way.
static func draw_cross(canvas: CanvasItem, centre: Vector2, half: float, colour: Color, width: float) -> void:
	var a: Vector2 = Vector2(half, half)
	var b: Vector2 = Vector2(half, -half)
	canvas.draw_line(centre - a, centre + a, colour, width, true)
	canvas.draw_line(centre - b, centre + b, colour, width, true)
