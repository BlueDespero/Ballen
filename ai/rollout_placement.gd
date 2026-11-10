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


func _init(p_candidates: int = 4, p_simulations: int = 8, temper: float = 0.1) -> void:
	candidates = p_candidates
	simulations = p_simulations
	_playouts = Playouts.new(temper)
	_model = AIController.normal_model()
	_hiding = ExposurePlacement.new(_model)


func choose(view: PublicView, exposure: Belief, rng: RandomNumberGenerator) -> Vector2i:
	var cells: Array[Vector2i] = view.own_legal_cells()
	if cells.size() <= 1 or simulations <= 0:
		return _hiding.choose(view, exposure, rng)
	_playouts.update(view)
	var ranked: Array[Vector2i] = best_hiding(view, exposure, cells)
	var seeds: Array[int] = []
	for i: int in simulations:
		seeds.append(rng.randi())
	var best: Vector2i = ranked[0]
	var best_total: float = -INF
	for cell: Vector2i in ranked.slice(0, candidates):
		var total: float = 0.0
		for seed_value: int in seeds:
			var playout_rng: RandomNumberGenerator = RandomNumberGenerator.new()
			playout_rng.seed = seed_value
			total += _playouts.play(view, playout_rng, cell)
		if total > best_total + 1e-9:
			best_total = total
			best = cell
	return best


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
