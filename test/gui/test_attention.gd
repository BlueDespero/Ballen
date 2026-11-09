extends GutTest

# The "act here" cue outlines one control, pulses when it lands there, then
# holds still; with reduced motion it never pulses.

## Long enough for every pulse to finish.
const PULSES_DONE: float = Attention.PULSES * 2 * Attention.PULSE_SECONDS + 0.2

var _target: Control
var _cue: Attention


func before_each() -> void:
	_target = Control.new()
	_target.position = Vector2(100, 50)
	_target.size = Vector2(80, 40)
	add_child_autofree(_target)
	_cue = Attention.new()
	add_child_autofree(_cue)


func test_it_is_hidden_without_a_target() -> void:
	assert_false(_cue.visible)


func test_it_outlines_its_target_with_a_margin() -> void:
	_cue.target = _target
	assert_true(_cue.visible)
	assert_eq(_cue.get_global_rect(), _target.get_global_rect().grow(Attention.MARGIN))


func test_it_follows_its_target() -> void:
	_cue.target = _target
	_target.position = Vector2(300, 200)
	await wait_process_frames(2)
	assert_eq(_cue.get_global_rect(), _target.get_global_rect().grow(Attention.MARGIN))


func test_it_hides_with_its_target_and_when_cleared() -> void:
	_cue.target = _target
	_target.visible = false
	await wait_process_frames(2)
	assert_false(_cue.visible, "target hidden")
	_target.visible = true
	_cue.target = null
	await wait_process_frames(2)
	assert_false(_cue.visible, "no target")


func test_it_pulses_then_holds_still() -> void:
	_cue.target = _target
	await wait_seconds(Attention.PULSE_SECONDS / 2.0)
	assert_gt(_cue.swell, 0.0, "pulsing as it lands")
	await wait_seconds(PULSES_DONE)
	assert_eq(_cue.swell, 0.0, "still once the pulses are done")


func test_a_new_target_pulses_again() -> void:
	_cue.target = _target
	await wait_seconds(PULSES_DONE)
	var other: Control = Control.new()
	other.size = Vector2(20, 20)
	add_child_autofree(other)
	_cue.target = other
	await wait_seconds(Attention.PULSE_SECONDS / 2.0)
	assert_gt(_cue.swell, 0.0)


func test_reduced_motion_holds_still_from_the_start() -> void:
	_cue.reduced_motion = true
	_cue.target = _target
	await wait_seconds(Attention.PULSE_SECONDS / 2.0)
	assert_eq(_cue.swell, 0.0)


func test_pulse_ends_at_rest() -> void:
	var dimmed: Control = Control.new()
	add_child_autofree(dimmed)
	var tween: Tween = Attention.pulse(dimmed, dimmed, "modulate:a", 0.4, 1.0)
	await wait_seconds(Attention.PULSE_SECONDS / 2.0)
	assert_lt(dimmed.modulate.a, 1.0, "dims during a pulse")
	await wait_seconds(PULSES_DONE)
	assert_false(tween.is_running(), "stops after its pulses")
	assert_eq(dimmed.modulate.a, 1.0, "back at rest")
