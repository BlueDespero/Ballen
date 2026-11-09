class_name Belief
extends RefCounted

## What the AI believes about the opponent's secret rule, from a PublicView
## only (ADR 0002): a probability for each rule of the opponent's deck.
##
## Two halves, as in docs/ai-decision-theory-research.md. The hard half is
## certain: a placement rules out the rules that forbid its cell, a skip the
## rules that allowed some cell (as Deduction does), and a ruled-out rule never
## comes back. The soft half asks how likely each remaining rule made the
## chosen cell, by the AI's OpponentModel, and adds its log to the rule's score.
## Each event is judged on the position just before it (MatchPosition.before).
##
## Built about_viewer, it is the same reasoning turned on the viewer's own
## rules: what an opponent using this model could believe about them from the
## viewer's public moves (how close the AI is to being found out).
##
## update() reads only the history events it hasn't seen, so the AI can keep
## one Belief through a match; a view whose history doesn't continue the one it
## saw (a new match or a rematch) starts it afresh.

## Probabilities closer than this are a tie.
const TIE: float = 1e-9

var _model: OpponentModel
## Whether the belief is about the viewer's own rules rather than the opponent's.
var _about_viewer: bool = false
## The player whose rules this is about.
var _player: int = Players.NONE
var _rules: Array[Rule] = []
var _alive: Array[bool] = []
var _log_scores: Array[float] = []
## How many history events have been read, and the last of them, to tell a
## continuation of the same history from a new one.
var _seen: int = 0
var _last_seen: HistoryEntry = null


func _init(model: OpponentModel, about_viewer: bool = false) -> void:
	_model = model
	_about_viewer = about_viewer


## A belief about the opponent of view's viewer (or, about_viewer, about the
## viewer's own rules), from the whole history.
static func of(view: PublicView, model: OpponentModel, about_viewer: bool = false) -> Belief:
	var belief: Belief = Belief.new(model, about_viewer)
	belief.update(view)
	return belief


## Reads the history events of view not read yet.
func update(view: PublicView) -> void:
	if not _continues(view):
		_reset(view)
	var history: Array[HistoryEntry] = view.position.history
	for i: int in range(_seen, history.size()):
		_observe(view.position, i)
	_seen = history.size()
	_last_seen = history[-1].copy() if not history.is_empty() else null


## The opponent's rules not ruled out, in deck order.
func alive() -> Array[Rule]:
	var rules: Array[Rule] = []
	for i: int in _rules.size():
		if _alive[i]:
			rules.append(_rules[i])
	return rules


## Each rule's probability by rule id; 0 for a ruled-out rule. They sum to 1.
func probabilities() -> Dictionary[String, float]:
	var best: float = -INF
	for i: int in _rules.size():
		if _alive[i]:
			best = maxf(best, _log_scores[i])
	var total: float = 0.0
	var weights: Array[float] = []
	for i: int in _rules.size():
		var weight: float = exp(_log_scores[i] - best) if _alive[i] else 0.0
		weights.append(weight)
		total += weight
	var result: Dictionary[String, float] = {}
	for i: int in _rules.size():
		# Every rule ruled out (a view that contradicts itself): all 0.
		result[_rules[i].id] = weights[i] / total if total > 0.0 else 0.0
	return result


func probability(rule_id: String) -> float:
	return probabilities().get(rule_id, 0.0)


## The most likely rule, ties broken at random; null when none is left. The
## opponent's secret rule is never ruled out, so none is left only in a view
## that contradicts itself.
func top(rng: RandomNumberGenerator) -> Rule:
	var chances: Dictionary[String, float] = probabilities()
	var best: Array[Rule] = []
	var best_chance: float = TIE
	for rule: Rule in _rules:
		var chance: float = chances[rule.id]
		if chance > best_chance + TIE:
			best = []
			best_chance = chance
		if chance > best_chance - TIE:
			best.append(rule)
	if best.is_empty():
		return null
	return best[rng.randi_range(0, best.size() - 1)]


## How hidden the opponent's rule still is, in bits: 0 when only one rule is
## possible, log2(5) when all are equally likely.
func entropy() -> float:
	var bits: float = 0.0
	for chance: float in probabilities().values():
		if chance > 0.0:
			bits -= chance * log(chance) / log(2.0)
	return bits


func _continues(view: PublicView) -> bool:
	var history: Array[HistoryEntry] = view.position.history
	if _player != _subject(view) or _ids(_rules) != _ids(view.decks[_player].rules) or history.size() < _seen:
		return false
	if _seen == 0:
		return true
	return _same_event(history[_seen - 1], _last_seen)


func _reset(view: PublicView) -> void:
	_player = _subject(view)
	_rules = view.decks[_player].rules.duplicate()
	_alive = []
	_log_scores = []
	for _rule: Rule in _rules:
		_alive.append(true)
		_log_scores.append(0.0)
	_seen = 0
	_last_seen = null


## One history event: an opponent's placement or skip narrows the belief.
func _observe(position: MatchPosition, index: int) -> void:
	var event: HistoryEntry = position.history[index]
	if event.player != _player or not event.is_placement_or_skip():
		return
	var before: MatchPosition = position.before(index)
	var legal_by_rule: Dictionary[String, Array] = {}
	for rule: Rule in _rules:
		legal_by_rule[rule.id] = RuleChecker.legal_cells(rule, before, _player, event.colour)
	var placed: bool = event.type == HistoryEntry.Type.PLACEMENT
	var cell_weights: Dictionary[Vector2i, float] = {}
	if placed:
		cell_weights = _model.weights(legal_by_rule)
	for i: int in _rules.size():
		if not _alive[i]:
			continue
		var legal: Array = legal_by_rule[_rules[i].id]
		if not placed:
			# Skipped: the rule allowed no cell for this colour.
			_alive[i] = legal.is_empty()
		elif not legal.has(event.cell):
			_alive[i] = false
		else:
			_log_scores[i] += _model.temper * log(_model.likelihood(event.cell, legal, cell_weights))


func _subject(view: PublicView) -> int:
	return view.viewer if _about_viewer else view.opponent()


static func _ids(rules: Array[Rule]) -> Array[String]:
	var ids: Array[String] = []
	for rule: Rule in rules:
		ids.append(rule.id)
	return ids


static func _same_event(a: HistoryEntry, b: HistoryEntry) -> bool:
	return b != null and a.type == b.type and a.player == b.player and a.cell == b.cell \
		and a.colour == b.colour and a.rule_id == b.rule_id
