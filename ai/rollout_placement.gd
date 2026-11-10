class_name RolloutPlacement
extends PlacementStrategy

## Hard's placement by playouts: of the `candidates` cells that hide its
## secret rule best (ExposurePlacement), the one whose playouts of the rest of
## the match (Playouts) the AI wins most. Every candidate is played out from
## the same `simulations` seeds, so they are compared on the same imagined
## matches; ties go to the better-hiding cell.

var candidates: int
var simulations: int
var _playouts: Playouts
var _model: OpponentModel
var _hiding: ExposurePlacement
## A choice stopped at its deadline (see PlacementStrategy.deadline_msec): its
## view (by history length), the cells to try, the seeds, and the progress.
var _pending: bool = false
var _pending_key: int
var _cells: Array[Vector2i] = []
var _seeds: Array[int] = []
var _cell_index: int
var _seed_index: int
var _cell_total: float
var _best: Vector2i
var _best_total: float


func _init(p_candidates: int = 4, p_simulations: int = 8, temper: float = 0.1) -> void:
	candidates = p_candidates
	simulations = p_simulations
	_playouts = Playouts.new(temper)
	_model = AIController.normal_model()
	_hiding = ExposurePlacement.new(_model)


func is_pending() -> bool:
	return _pending


## With a deadline it plays as many playouts as fit, at least one, and carries
## on at the next choose() with the same view; the random draws are the same
## either way. When must_finish is set it picks among the cells played out in
## full so far.
func choose(view: PublicView, exposure: Belief, rng: RandomNumberGenerator) -> Vector2i:
	var key: int = view.position.history.size()
	if not (_pending and key == _pending_key):
		_pending = false
		var cells: Array[Vector2i] = view.own_legal_cells()
		if cells.size() <= 1 or simulations <= 0:
			return _hiding.choose(view, exposure, rng)
		_playouts.update(view)
		_cells = best_hiding(view, exposure, cells).slice(0, candidates)
		_seeds = []
		for i: int in simulations:
			_seeds.append(rng.randi())
		_pending_key = key
		_cell_index = 0
		_seed_index = 0
		_cell_total = 0.0
		_best = _cells[0]
		_best_total = -INF
	_pending = not _play(view)
	return PlacementStrategy.NO_CELL if _pending else _best


## Plays the remaining playouts, at least one, until the deadline; true once
## every cell has been played out.
func _play(view: PublicView) -> bool:
	var this_step: int = 0
	while _cell_index < _cells.size():
		if must_finish and _cell_index > 0:
			return true
		if this_step > 0 and deadline_msec > 0 and Time.get_ticks_msec() >= deadline_msec:
			return false
		var playout_rng: RandomNumberGenerator = RandomNumberGenerator.new()
		playout_rng.seed = _seeds[_seed_index]
		_cell_total += _playouts.play(view, playout_rng, _cells[_cell_index])
		this_step += 1
		_seed_index += 1
		if _seed_index == _seeds.size():
			if _cell_total > _best_total + 1e-9:
				_best_total = _cell_total
				_best = _cells[_cell_index]
			_cell_index += 1
			_seed_index = 0
			_cell_total = 0.0
	return true


## The cells, best hiding first: by how likely the opponent would find the
## secret rule after a placement there (ExposurePlacement.exposed_after).
func best_hiding(view: PublicView, exposure: Belief, cells: Array[Vector2i]) -> Array[Vector2i]:
	var chances: Dictionary[String, float] = exposure.probabilities()
	var legal_by_rule: Dictionary[String, Array] = {}
	for rule: Rule in view.decks[view.viewer].rules:
		legal_by_rule[rule.id] = RuleChecker.legal_cells(rule, view.position, view.viewer, view.position.colour)
	var cell_weights: Dictionary[Vector2i, float] = _model.weights(legal_by_rule)
	var exposed: Dictionary[Vector2i, float] = {}
	for cell: Vector2i in cells:
		exposed[cell] = _hiding.exposed_after(cell, chances, legal_by_rule, cell_weights, view.own_secret_rule.id)
	var ranked: Array[Vector2i] = cells.duplicate()
	ranked.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return exposed[a] < exposed[b])
	return ranked
