class_name BallView
extends Control

## A waiting ball beside the board. The player's can be dragged with the mouse
## or by touch (touch arrives as mouse events: emulate_mouse_from_touch is on
## by default). On release it asks `legality` (which asks the match) whether
## the cell under the pointer is legal: if so it emits `dropped`, otherwise it
## snaps back. It never decides legality itself.

## The ball was released on a legal cell.
signal dropped(cell: Vector2i)

const SNAP_BACK_SECONDS: float = 0.15

## Finds the cell under the pointer.
@export var board: BoardView
## Balls of the opponent carry the same mark as on the board.
@export var marked: bool = false

## Answers whether a cell is legal for this ball now: func(cell: Vector2i) -> bool.
var legality: Callable
## Whether the player may drag the ball now.
var draggable: bool = false:
	set(value):
		draggable = value
		mouse_default_cursor_shape = Control.CURSOR_DRAG if value else Control.CURSOR_ARROW
## The ball's colour; "" hides it.
var colour: String = "":
	set(value):
		colour = value
		visible = value != ""
		queue_redraw()

var _home: Vector2
var _dragging: bool = false
var _grab_offset: Vector2


func _ready() -> void:
	_home = position
	visible = colour != ""


## Puts the ball back on its waiting spot at once.
func reset() -> void:
	_dragging = false
	z_index = 0
	position = _home
	scale = Vector2.ONE
	modulate.a = 1.0


## Shows a ball of this colour on its waiting spot for hold_seconds, then
## fades it out over seconds while it shrinks: a skipped ball. Await it;
## reset() brings the view back.
func dissolve(ball_colour: String, hold_seconds: float, seconds: float) -> void:
	reset()
	colour = ball_colour
	pivot_offset = size / 2.0
	var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_interval(hold_seconds)
	tween.tween_property(self, "scale", Vector2(0.3, 0.3), seconds)
	tween.parallel().tween_property(self, "modulate:a", 0.0, seconds)
	await tween.finished


## Moves the ball to a point in canvas coordinates (e.g. a cell centre). Await it.
func fly_to(global_centre: Vector2, seconds: float) -> void:
	z_index = 1
	var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", global_centre - size / 2.0, seconds)
	await tween.finished


func _draw() -> void:
	if colour != "":
		BoardView.draw_ball(self, Rect2(Vector2.ZERO, size), colour, marked)


func _gui_input(event: InputEvent) -> void:
	if not draggable:
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_dragging = true
			_grab_offset = button.position
			z_index = 1
		elif _dragging:
			_dragging = false
			_drop(button.global_position)
		accept_event()
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and _dragging:
		global_position = motion.global_position - _grab_offset
		accept_event()


func _drop(global_point: Vector2) -> void:
	var cell: Vector2i = board.cell_at(global_point) if board != null else BoardView.NO_CELL
	if cell != BoardView.NO_CELL and legality.is_valid() and legality.call(cell):
		global_position = board.cell_centre(cell) - size / 2.0
		dropped.emit(cell)
		return
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", _home, SNAP_BACK_SECONDS)
	tween.tween_callback(reset)
