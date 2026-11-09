class_name Attention
extends Control

## The "act here" cue: an outline in the board's glow colour around the one
## control the player should use now. When it lands on a control it pulses a
## few times, then holds still: motion starting is what catches the eye, and a
## cue that never stops moving turns into noise. With reduced motion it holds
## still from the start. Colour is never its only signal: the outline is thick
## against the dark layout. Use one per screen, so only one control ever wears
## it. It ignores the mouse and draws on its own (top level), following its
## target as it moves.
##
## pulse() gives cues drawn their own way (the legal cells, the colour picker's
## rings, the lit Live button) the same rhythm.

## The outline sits this far outside its target.
const MARGIN: float = 4.0
const WIDTH: float = 3.0
## How much wider the outline grows at the peak of a pulse.
const PULSE_WIDTH: float = 3.0
const CORNER_RADIUS: int = 10
## How many times a cue pulses before it holds still.
const PULSES: int = 2
## One swell of a pulse, or its fade back.
const PULSE_SECONDS: float = 0.3

## Reduced motion: the outline holds still from the start.
var reduced_motion: bool = false:
	set(value):
		reduced_motion = value
		if value:
			_stop_pulse()

## The control the cue is on; null hides it. A new target pulses again.
var target: Control = null:
	set(value):
		if value == target:
			return
		target = value
		_follow()
		_stop_pulse()
		if target != null and not reduced_motion and is_inside_tree():
			_tween = pulse(self, self, "swell", 1.0, 0.0)

## How far into a pulse the outline is: 0 at rest, 1 at its peak.
var swell: float = 0.0:
	set(value):
		swell = value
		queue_redraw()

var _tween: Tween = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	visible = false


## Tweens object's property out to peak and back to rest PULSES times, then
## leaves it at rest. The tween belongs to owner, so it ends with it.
static func pulse(owner: Node, object: Object, property: NodePath, peak: Variant, rest: Variant) -> Tween:
	var tween: Tween = owner.create_tween().set_loops(PULSES)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(object, property, peak, PULSE_SECONDS)
	tween.tween_property(object, property, rest, PULSE_SECONDS)
	return tween


func _process(_delta: float) -> void:
	_follow()


func _draw() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = BoardView.GLOW_COLOUR
	style.set_border_width_all(roundi(WIDTH + PULSE_WIDTH * swell))
	style.set_corner_radius_all(CORNER_RADIUS)
	draw_style_box(style, Rect2(Vector2.ZERO, size))


## Covers the target, grown by MARGIN; hidden while there is no target or it
## is hidden.
func _follow() -> void:
	visible = target != null and is_instance_valid(target) and target.is_visible_in_tree()
	if not visible:
		return
	var rect: Rect2 = target.get_global_rect().grow(MARGIN)
	if rect != get_global_rect():
		global_position = rect.position
		size = rect.size


func _stop_pulse() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	swell = 0.0
