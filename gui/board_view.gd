class_name BoardView
extends Control

## Draws the board: its cells, the balls on them, the glow on legal cells, a
## ring around one highlighted ball (a past turn's, in the history view) and
## the row numbers along its left edge. It shows what it is given and never
## decides what is legal. Row y = 0 is drawn at the top (the AI's side), y = 5
## at the bottom (the player's side); row numbers count from the first player's
## side, so they run 1-6 upwards or downwards depending on who went first.

const NO_CELL: Vector2i = Vector2i(-1, -1)
const CELL_SIZE: float = 80.0
const CELL_TEXTURE: Texture2D = preload("res://assets/Tiles/resized048.png")
const BALL_TEXTURE: Texture2D = preload("res://assets/Tiles/Large tiles/Thin outline/resized039.png")
const BALL_INSET: float = 8.0
## The "act here" colour: legal cells glow in it, and the colour picker's ring
## and the lit Live button share it.
const GLOW_COLOUR: Color = Color(1.0, 0.92, 0.45)
const OPPONENT_MARK_COLOUR: Color = Color(0.08, 0.09, 0.11, 0.85)
const HIGHLIGHT_COLOUR: Color = Color(1.0, 1.0, 1.0)
const HIGHLIGHT_WIDTH: float = 4.0
## Row labels sit in a strip this wide left of the board, right-aligned with a gap.
const ROW_LABEL_WIDTH: float = 20.0
const ROW_LABEL_GAP: float = 4.0
const ROW_LABEL_FONT_SIZE: int = 16
const ROW_LABEL_COLOUR: Color = Color(0.78, 0.81, 0.86, 0.75)

## Reduced motion: the legal-cell glow holds steady instead of pulsing.
var reduced_motion: bool = false:
	set(value):
		reduced_motion = value
		queue_redraw()
## Colour-blind mode: each ball shows its colour's symbol.
var symbols: bool = false:
	set(value):
		symbols = value
		queue_redraw()

var _board: Board = Board.new()
var _legal_cells: Array[Vector2i] = []
var _viewer: int = Players.NONE
var _first_player: int = 0
var _highlighted: Vector2i = NO_CELL


func _ready() -> void:
	custom_minimum_size = Vector2.ONE * CELL_SIZE * Board.SIZE


## Shows a board. Glows on legal_cells; balls not owned by viewer are marked;
## rows are numbered from first_player's side; the ball on highlighted (if
## any) gets a ring.
func show_board(board: Board, legal_cells: Array[Vector2i], viewer: int, first_player: int,
		highlighted: Vector2i = NO_CELL) -> void:
	_board = board
	_legal_cells = legal_cells.duplicate()
	_viewer = viewer
	_first_player = first_player
	_highlighted = highlighted
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
## get a dark dot in the middle. With symbols (colour-blind mode) the ball
## also shows its colour's symbol: outlined on the player's balls, white on a
## bigger dark dot on the opponent's.
static func draw_ball(canvas: CanvasItem, rect: Rect2, colour: String, marked: bool, symbols: bool = false) -> void:
	canvas.draw_texture_rect(BALL_TEXTURE, rect, false, Constants.colors[colour]["rgb"])
	var centre: Vector2 = rect.get_center()
	if not symbols:
		if marked:
			canvas.draw_circle(centre, rect.size.x * 0.14, OPPONENT_MARK_COLOUR)
		return
	if marked:
		canvas.draw_circle(centre, rect.size.x * 0.27, OPPONENT_MARK_COLOUR)
		BallSymbol.draw(canvas, centre, rect.size.x * 0.15, colour, false)
	else:
		BallSymbol.draw(canvas, centre, rect.size.x * 0.2, colour, true)


func _process(_delta: float) -> void:
	if not _legal_cells.is_empty() and not reduced_motion:
		queue_redraw() # the glow pulses


func _draw() -> void:
	# With reduced motion the glow holds steady at its middle brightness.
	var pulse: float = 0.5 if reduced_motion else 0.5 + 0.5 * sin(Time.get_ticks_msec() / 250.0)
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
			draw_ball(self, rect.grow(-BALL_INSET), ball.colour, ball.owner != _viewer, symbols)
	if Board.contains(_highlighted):
		var centre: Vector2 = _cell_rect(_highlighted).get_center()
		draw_arc(centre, CELL_SIZE / 2.0 - BALL_INSET / 2.0, 0.0, TAU, 48, HIGHLIGHT_COLOUR, HIGHLIGHT_WIDTH, true)
	_draw_row_labels()


func _draw_row_labels() -> void:
	var font: Font = get_theme_default_font()
	var baseline_offset: float = (font.get_ascent(ROW_LABEL_FONT_SIZE) - font.get_descent(ROW_LABEL_FONT_SIZE)) / 2.0
	for y: int in Board.SIZE:
		var row: int = Board.row_number(Vector2i(0, y), _first_player)
		var baseline: Vector2 = Vector2(-ROW_LABEL_GAP - ROW_LABEL_WIDTH, (y + 0.5) * CELL_SIZE + baseline_offset)
		draw_string(font, baseline, str(row), HORIZONTAL_ALIGNMENT_RIGHT, ROW_LABEL_WIDTH,
			ROW_LABEL_FONT_SIZE, ROW_LABEL_COLOUR)


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell) * CELL_SIZE, Vector2.ONE * CELL_SIZE)
