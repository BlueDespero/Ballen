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


## A filled ◀ (direction -1) or ▶ (direction 1) centred on centre, half its
## height above and below and about as wide as it is tall.
static func draw_triangle(canvas: CanvasItem, centre: Vector2, half: float, direction: int, colour: Color) -> void:
	var tip: Vector2 = centre + Vector2(half * 0.9 * direction, 0.0)
	var back: float = centre.x - half * 0.9 * direction
	var points: PackedVector2Array = PackedVector2Array([tip, Vector2(back, centre.y - half), Vector2(back, centre.y + half)])
	canvas.draw_colored_polygon(points, colour)
