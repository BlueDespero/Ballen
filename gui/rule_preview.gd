class_name RulePreview
extends Control

## A small board on the match setup screen that shows what picking a secret
## rule means: a fixed position from the middle of a match, with the cells the
## rule would let the player place on next glowing, as they will in the match.
## Player 0 is the player (the bottom side, and first to play); the AI's balls
## carry its mark. It shows what it is given and never decides legality: the
## glow comes from RuleChecker on SAMPLE.

const CELL_SIZE: float = 22.0
const BALL_INSET: float = 2.0
const GLOW_ALPHA: float = 0.45
const GLOW_BORDER: float = 2.0
## Once a rule is picked, the cells it forbids darken so the glowing ones stand out.
const FORBIDDEN_SHADE: Color = Color(0.0, 0.0, 0.0, 0.45)

## Placements in the sample, in order: the player first, then turn about.
## Rules that read the last ball, rows or turns all have something to read.
const _SAMPLE_MOVES: Array[Array] = [
	[Vector2i(1, 4), "red"], [Vector2i(4, 1), "yellow"],
	[Vector2i(2, 3), "green"], [Vector2i(3, 2), "blue"],
	[Vector2i(4, 4), "yellow"], [Vector2i(1, 1), "red"],
	[Vector2i(3, 4), "blue"], [Vector2i(2, 1), "green"],
]
## The colour the AI hands the player for their next ball.
const _SAMPLE_COLOUR: String = "blue"

## The rule whose cells glow; null shows the position alone.
var rule: Rule = null:
	set(value):
		rule = value
		legal_cells = []
		if value != null:
			legal_cells = RuleChecker.legal_cells(value, sample, 0, sample.colour)
		queue_redraw()
## The cells glowing now.
var legal_cells: Array[Vector2i] = []
## Colour-blind mode: each ball shows its colour's symbol.
var symbols: bool = false:
	set(value):
		symbols = value
		queue_redraw()
## The position the preview shows.
var sample: MatchPosition = sample_position()


func _init() -> void:
	custom_minimum_size = Vector2.ONE * CELL_SIZE * Board.SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## A position in the middle of a match, at the start of the player's fifth
## turn: four balls each, the player placing blue.
static func sample_position() -> MatchPosition:
	var position: MatchPosition = MatchPosition.new(Board.new(), 0)
	var player: int = 0
	for move: Array in _SAMPLE_MOVES:
		var cell: Vector2i = move[0]
		var colour: String = move[1]
		position.history.append(HistoryEntry.colour_pick(Players.opponent(player), colour))
		position.turn += 1
		position.board.place(cell, Ball.new(colour, player))
		position.history.append(HistoryEntry.placement(player, cell, colour))
		player = Players.opponent(player)
	position.history.append(HistoryEntry.colour_pick(Players.opponent(player), _SAMPLE_COLOUR))
	position.turn += 1
	position.colour = _SAMPLE_COLOUR
	return position


func _draw() -> void:
	for cell: Vector2i in Board.all_cells():
		var rect: Rect2 = Rect2(Vector2(cell) * CELL_SIZE, Vector2.ONE * CELL_SIZE)
		draw_texture_rect(BoardView.CELL_TEXTURE, rect, false)
		if rule != null and not legal_cells.has(cell):
			draw_rect(rect, FORBIDDEN_SHADE, true)
		if legal_cells.has(cell):
			draw_rect(rect.grow(-1.0), Color(BoardView.GLOW_COLOUR, GLOW_ALPHA), true)
			draw_rect(rect.grow(-1.0), BoardView.GLOW_COLOUR, false, GLOW_BORDER)
		var ball: Ball = sample.board.ball_at(cell)
		if ball != null:
			BoardView.draw_ball(self, rect.grow(-BALL_INSET), ball.colour, ball.owner != 0, symbols)
