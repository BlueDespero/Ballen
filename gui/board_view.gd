class_name BoardView
extends Control

## Draws the board: its cells, the balls on them and the glow on legal cells.
## It shows what it is given and never decides what is legal. Row y = 0 is
## drawn at the top (the AI's side), y = 5 at the bottom (the player's side).

const NO_CELL: Vector2i = Vector2i(-1, -1)
const CELL_SIZE: float = 80.0
const CELL_TEXTURE: Texture2D = preload("res://assets/Tiles/resized048.png")
const BALL_TEXTURE: Texture2D = preload("res://assets/Tiles/Large tiles/Thin outline/resized039.png")
const BALL_INSET: float = 8.0
const GLOW_COLOUR: Color = Color(1.0, 0.92, 0.45)
const OPPONENT_MARK_COLOUR: Color = Color(0.08, 0.09, 0.11, 0.85)

var _board: Board = Board.new()
var _legal_cells: Array[Vector2i] = []
var _viewer: int = Players.NONE


func _ready() -> void:
	custom_minimum_size = Vector2.ONE * CELL_SIZE * Board.SIZE


## Shows a board. Glows on legal_cells; balls not owned by viewer are marked.
func show_board(board: Board, legal_cells: Array[Vector2i], viewer: int) -> void:
	_board = board
	_legal_cells = legal_cells.duplicate()
	_viewer = viewer
	queue_redraw()


## The cell under a point in canvas coordinates; NO_CELL off the board.
func cell_at(global_point: Vector2) -> Vector2i:
	var local: Vector2 = get_global_transform().affine_inverse() * global_point
	var cell: Vector2i = Vector2i(floori(local.x / CELL_SIZE), floori(local.y / CELL_SIZE))
	return cell if Board.contains(cell) else NO_CELL


## The centre of a cell in canvas coordinates.
func cell_centre(cell: Vector2i) -> Vector2:
	return get_global_transform() * _cell_rect(cell).get_center()


## Draws one ball into rect on any canvas item; marked balls (the opponent's)
## get a dark dot in the middle.
static func draw_ball(canvas: CanvasItem, rect: Rect2, colour: String, marked: bool) -> void:
	canvas.draw_texture_rect(BALL_TEXTURE, rect, false, Constants.colors[colour]["rgb"])
	if marked:
		canvas.draw_circle(rect.get_center(), rect.size.x * 0.14, OPPONENT_MARK_COLOUR)


func _process(_delta: float) -> void:
	if not _legal_cells.is_empty():
		queue_redraw() # the glow pulses


func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 250.0)
	for cell: Vector2i in Board.all_cells():
		var rect: Rect2 = _cell_rect(cell)
		draw_texture_rect(CELL_TEXTURE, rect, false)
		if _legal_cells.has(cell):
			var glow: Color = GLOW_COLOUR
			glow.a = 0.3 + 0.2 * pulse
			draw_rect(rect.grow(-5.0), glow, true)
			draw_rect(rect.grow(-5.0), GLOW_COLOUR, false, 3.0)
		var ball: Ball = _board.ball_at(cell)
		if ball != null:
			draw_ball(self, rect.grow(-BALL_INSET), ball.colour, ball.owner != _viewer)


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell) * CELL_SIZE, Vector2.ONE * CELL_SIZE)
