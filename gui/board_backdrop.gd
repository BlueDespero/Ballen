class_name BoardBackdrop
extends Control

## Background art for the menus: dim board cells filling the rect,
## where every SPAWN_SECONDS a ball in a random colour drops into an empty
## cell, rests, then fades, so about 10 are on screen at a time. With reduced
## motion it shows a still scatter of balls instead. It never takes the mouse.
## advance() moves the balls on by a time step, so tests can drive it with a
## seeded rng instead of waiting for frames.

## A new ball every this many seconds.
const SPAWN_SECONDS: float = 0.6
## A ball's whole life: drop, rest, fade.
const LIFETIME: float = 6.0
const DROP_SECONDS: float = 0.5
const FADE_IN_SECONDS: float = 0.2
const FADE_SECONDS: float = 1.2
## A ball starts its drop this many cells above its cell, a little bigger.
const DROP_HEIGHT: float = 0.75
const DROP_GROWTH: float = 0.25
## How many balls the animation keeps on screen (LIFETIME / SPAWN_SECONDS),
## and how many the still scatter shows.
const MIN_BALLS: int = 8
const MAX_BALLS: int = 12
const SCATTER_BALLS: int = 10
const CELL_SIZE: float = BoardView.CELL_SIZE
## The cells and balls are darkened so the menus over them stay readable.
const CELL_TINT: Color = Color(0.3, 0.32, 0.37)
const BALL_TINT: Color = Color(0.8, 0.8, 0.8)


## One ball: where it lands, its colour, and how long ago it started its drop.
class FallingBall:
	var cell: Vector2i
	var colour: String
	var age: float

	func _init(ball_cell: Vector2i, ball_colour: String, ball_age: float) -> void:
		cell = ball_cell
		colour = ball_colour
		age = ball_age


## Reduced motion: a still scatter, no falling balls. Takes effect on start().
var reduced_motion: bool = false:
	set(value):
		reduced_motion = value
		_started = false
## Picks the cells and colours; replace it with a seeded one for repeatable balls.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## The balls on screen.
var balls: Array[FallingBall] = []

var _started: bool = false
var _until_next: float = 0.0


func _init() -> void:
	rng.randomize()
	mouse_filter = MOUSE_FILTER_IGNORE
	clip_contents = true # the partial cells at the edges stop at the rect


func _ready() -> void:
	Settings.changed.connect(_apply_settings)
	reduced_motion = Settings.reduced_motion


## How far above its cell a ball of this age is, as a share of DROP_HEIGHT:
## 1 as it starts, easing out to 0 once it lands.
static func fall(age: float) -> float:
	var t: float = clampf(age / DROP_SECONDS, 0.0, 1.0)
	return pow(1.0 - t, 3.0)


## How opaque a ball of this age is: it fades in as it drops, stays solid
## while it rests, and fades out over the last FADE_SECONDS of its life.
static func alpha(age: float) -> float:
	return clampf(minf(age / FADE_IN_SECONDS, (LIFETIME - age) / FADE_SECONDS), 0.0, 1.0)


## Columns and rows of cells needed to cover the rect, centred, with partial
## cells at the edges.
func cells_across() -> Vector2i:
	return Vector2i(ceili(size.x / CELL_SIZE), ceili(size.y / CELL_SIZE))


## Fills the cells afresh: a still scatter with reduced motion, otherwise the
## balls as if the animation had been running for a whole LIFETIME.
func start() -> void:
	balls.clear()
	_until_next = 0.0
	_started = cells_across().x > 0 and cells_across().y > 0
	if not _started:
		return
	if reduced_motion:
		for i: int in SCATTER_BALLS:
			_spawn(DROP_SECONDS)
	else:
		for i: int in ceili(LIFETIME / SPAWN_SECONDS):
			advance(SPAWN_SECONDS)
	queue_redraw()


## Moves the animation on by delta seconds: balls age, a new one drops in every
## SPAWN_SECONDS, and faded ones go. Does nothing with reduced motion.
func advance(delta: float) -> void:
	if reduced_motion:
		return
	for ball: FallingBall in balls:
		ball.age += delta
	_until_next -= delta
	while _until_next <= 0.0:
		_spawn(-_until_next)
		_until_next += SPAWN_SECONDS
	_keep(func(ball: FallingBall) -> bool: return ball.age < LIFETIME)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if not _started:
		start()
	if _started and not reduced_motion:
		advance(delta)
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		var cells: Rect2i = Rect2i(Vector2i.ZERO, cells_across())
		_keep(func(ball: FallingBall) -> bool: return cells.has_point(ball.cell))
		queue_redraw()


func _draw() -> void:
	var cells: Vector2i = cells_across()
	for y: int in cells.y:
		for x: int in cells.x:
			draw_texture_rect(BoardView.CELL_TEXTURE, _cell_rect(Vector2i(x, y)), false, CELL_TINT)
	for ball: FallingBall in balls:
		var rect: Rect2 = _cell_rect(ball.cell).grow(-BoardView.BALL_INSET)
		var fall_share: float = fall(ball.age)
		rect = rect.grow(rect.size.x * DROP_GROWTH * fall_share / 2.0)
		rect.position.y -= fall_share * DROP_HEIGHT * CELL_SIZE
		var tint: Color = BALL_TINT
		tint.a = alpha(ball.age)
		BoardView.draw_ball(self, rect, ball.colour, false, false, tint)


func _apply_settings() -> void:
	if Settings.reduced_motion != reduced_motion:
		reduced_motion = Settings.reduced_motion


## A ball of this age in a random empty cell, in a random colour; none if the
## cells are all taken.
func _spawn(age: float) -> void:
	var taken: Dictionary[Vector2i, bool] = {}
	for ball: FallingBall in balls:
		taken[ball.cell] = true
	var empty: Array[Vector2i] = []
	var cells: Vector2i = cells_across()
	for y: int in cells.y:
		for x: int in cells.x:
			if not taken.has(Vector2i(x, y)):
				empty.append(Vector2i(x, y))
	if empty.is_empty():
		return
	var cell: Vector2i = empty[rng.randi_range(0, empty.size() - 1)]
	var colour: String = BallColour.ALL[rng.randi_range(0, BallColour.ALL.size() - 1)]
	balls.append(FallingBall.new(cell, colour, age))


func _keep(wanted: Callable) -> void:
	var kept: Array[FallingBall] = []
	for ball: FallingBall in balls:
		if wanted.call(ball):
			kept.append(ball)
	balls = kept


func _cell_rect(cell: Vector2i) -> Rect2:
	var origin: Vector2 = ((size - Vector2(cells_across()) * CELL_SIZE) / 2.0).floor()
	return Rect2(origin + Vector2(cell) * CELL_SIZE, Vector2.ONE * CELL_SIZE)
