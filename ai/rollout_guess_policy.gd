class_name RolloutGuessPolicy
extends GuessPolicy

## Hard's guessing with V_wait from playouts (docs/ai-decision-theory-research.md,
## "Guess when confidence beats the value of waiting"). Guessing the top rule
## now is worth 2p − 1 (win +1, loss −1). Waiting is worth the average result
## of `simulations` playouts of the match from here in which the AI doesn't
## guess at this decision (Playouts). It guesses when 2p − 1 ≥ that average.
## p comes from the playouts' tempered belief.
##
## With a deadline (GuessPolicy.deadline_msec) it plays on until then, part of
## a playout if need be, and carries on at the next choose() with the same view; the
## random draws are the same either way, so a seeded match plays the same.
## When must_finish is set it decides on the playouts played so far.

## Settles with fewer playouts than this (must_finish), the average is too
## noisy to bet the match on: it decides as Hard's one-step policy instead.
const FEWEST_PLAYOUTS: int = 8

var simulations: int
var _playouts: Playouts
## A decision stopped at its deadline (see GuessPolicy.deadline_msec): its view
## (by history length and phase), its top rule and chance, and the playouts so far.
var _pending: bool = false
var _pending_key: Vector2i
var _top: Rule
var _chance: float
var _played: int
var _total: float
var _current: Playouts.Playout = null
var _one_step: ValueGuessPolicy = ValueGuessPolicy.new()
var _belief_seen: Belief
var _exposure_seen: Belief


func _init(p_simulations: int = 16, temper: float = 0.1) -> void:
	super(1.0)
	simulations = p_simulations
	_playouts = Playouts.new(temper)


func is_pending() -> bool:
	return _pending


func choose(belief_now: Belief, exposure: Belief, view: PublicView, rng: RandomNumberGenerator) -> Rule:
	_belief_seen = belief_now
	_exposure_seen = exposure
	var key: Vector2i = Vector2i(view.position.history.size(), view.phase)
	if not (_pending and key == _pending_key):
		_pending = false
		last_closeness = 0.0
		_playouts.update(view)
		var belief: Belief = _playouts.belief
		_top = belief.top(rng)
		if _top == null or belief.probability(_top.id) <= 0.0:
			return null
		_chance = belief.probability(_top.id)
		if _chance >= 1.0 - TOLERANCE:
			return _top
		_pending_key = key
		_played = 0
		_total = 0.0
		_current = null
	_pending = not _play(view, rng)
	if _pending:
		return null
	if _played == 0 or _played < mini(FEWEST_PLAYOUTS, simulations):
		var guess: Rule = _one_step.choose(_belief_seen, _exposure_seen, view, rng)
		last_closeness = _one_step.last_closeness
		return guess
	var waiting: float = _total / _played
	last_closeness = clampf(1.0 - absf(2.0 * _chance - 1.0 - waiting) / (2.0 * CLEAR_MARGIN), 0.0, 1.0)
	return _top if 2.0 * _chance - 1.0 >= waiting else null


## The average result for the AI (1 win, −1 loss, 0 draw) of playing on from
## the view without guessing now, all playouts at once.
func value_of_waiting(view: PublicView, rng: RandomNumberGenerator) -> float:
	_playouts.update(view)
	if simulations <= 0:
		return 0.0
	var total: float = 0.0
	for i: int in simulations:
		total += _one_playout(view, rng)
	return total / simulations


## Plays the decision's remaining playouts until the deadline (at least one
## command of one); true once all are played.
func _play(view: PublicView, rng: RandomNumberGenerator) -> bool:
	var finished_one: bool = false
	while _played < simulations:
		if must_finish and _played > 0:
			_current = null
			return true
		if finished_one and deadline_msec > 0 and Time.get_ticks_msec() >= deadline_msec:
			return false
		if _current == null:
			var playout_rng: RandomNumberGenerator = RandomNumberGenerator.new()
			playout_rng.seed = rng.randi()
			_current = _playouts.start(view, playout_rng)
		if not _current.run(deadline_msec):
			return false
		_total += _current.value
		_current = null
		_played += 1
		finished_one = true
	return true


func _one_playout(view: PublicView, rng: RandomNumberGenerator) -> float:
	var playout_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	playout_rng.seed = rng.randi()
	return _playouts.play(view, playout_rng)
