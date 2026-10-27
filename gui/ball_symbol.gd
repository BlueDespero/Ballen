class_name BallSymbol
extends RefCounted

## Colour-blind mode: a distinct symbol for each ball colour, so balls can be
## told apart by shape as well as colour. Yellow is a triangle, blue a
## square, red a cross and green a ring. Drawn rather than taken from icon
## art (no Game Icons pack in assets/ yet), so every ball skin can use it.

const FILL: Color = Color(1.0, 1.0, 1.0)
const OUTLINE: Color = Color(0.08, 0.09, 0.11, 0.9)
const OUTLINE_WIDTH: float = 2.0


## Draws colour's symbol centred on centre, about radius in size. With
## outlined, a dark edge keeps it readable on the bright ball colours;
## without, it is meant for a dark background (the opponent's mark).
static func draw(canvas: CanvasItem, centre: Vector2, radius: float, colour: String, outlined: bool) -> void:
	if outlined:
		_draw_shape(canvas, centre, radius, colour, OUTLINE, OUTLINE_WIDTH)
	_draw_shape(canvas, centre, radius, colour, FILL, 0.0)


## One pass of the shape; grow > 0 draws it that much bigger all round (the
## outline pass, drawn first).
static func _draw_shape(canvas: CanvasItem, centre: Vector2, radius: float, colour: String,
		ink: Color, grow: float) -> void:
	match colour:
		BallColour.YELLOW:
			# A triangle looks smaller than a square of the same radius.
			var r: float = radius * 1.15 + grow * 2.0
			var points: PackedVector2Array = PackedVector2Array([
				centre + Vector2(0.0, -r),
				centre + Vector2(0.87 * r, 0.55 * r),
				centre + Vector2(-0.87 * r, 0.55 * r),
			])
			canvas.draw_colored_polygon(points, ink)
		BallColour.BLUE:
			var half: float = radius * 0.72 + grow
			canvas.draw_rect(Rect2(centre - Vector2(half, half), Vector2(half, half) * 2.0), ink)
		BallColour.RED:
			var arm: float = radius * 0.8 + grow
			var width: float = radius * 0.42 + grow * 2.0
			canvas.draw_line(centre + Vector2(-arm, -arm), centre + Vector2(arm, arm), ink, width, true)
			canvas.draw_line(centre + Vector2(-arm, arm), centre + Vector2(arm, -arm), ink, width, true)
		BallColour.GREEN:
			var width: float = radius * 0.38 + grow * 2.0
			canvas.draw_arc(centre, radius * 0.8, 0.0, TAU, 32, ink, width, true)
