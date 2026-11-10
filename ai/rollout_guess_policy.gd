class_name RolloutGuessPolicy
extends GuessPolicy

## Hard's guessing with V_wait from playouts (docs/ai-decision-theory-research.md,
## "Guess when confidence beats the value of waiting"; DMU §4.6, Monte Carlo
## evaluation). Guessing the top rule now is worth 2p − 1 (win +1, loss −1).
## Waiting is worth the average result of `simulations` playouts of the match
## from here, each with the opponent's secret rule drawn from the belief:
## the opponent plays as Normal, the AI as Hard's pieces, and the AI doesn't
## guess at this decision. It guesses when 2p − 1 ≥ that average.
##
## The playouts and p use their own belief, tempered by `temper`: the AI's
## usual belief is overconfident against a player who hides
## (docs/ai-internals.md, "Calibration"), and drawing from it makes waiting
## look worse than it is.

## More commands than any playout needs; one still running is counted a draw.
const MAX_COMMANDS: int = 500

var simulations: int
var _belief: Belief


func _init(p_simulations: int = 16, temper: float = 0.1) -> void:
	super(1.0)
	simulations = p_simulations
	_belief = Belief.new(HiderModel.new(1.0, 0.2, temper))


func choose(_belief_unused: Belief, _exposure: Belief, view: PublicView, rng: RandomNumberGenerator) -> Rule:
	last_closeness = 0.0
	_belief.update(view)
	var top: Rule = _belief.top(rng)
	if top == null or _belief.probability(top.id) <= 0.0:
		return null
	var chance: float = _belief.probability(top.id)
	if chance >= 1.0 - TOLERANCE:
		return top
	var waiting: float = value_of_waiting(view, rng)
	last_closeness = clampf(1.0 - absf(2.0 * chance - 1.0 - waiting) / (2.0 * CLEAR_MARGIN), 0.0, 1.0)
	return top if 2.0 * chance - 1.0 >= waiting else null


## The average result for the AI (1 win, −1 loss, 0 draw) of playing on from
## the view without guessing now.
func value_of_waiting(view: PublicView, rng: RandomNumberGenerator) -> float:
	_belief.update(view)
	if simulations <= 0:
		return 0.0
	var total: float = 0.0
	for i: int in simulations:
		var playout_rng: RandomNumberGenerator = RandomNumberGenerator.new()
		playout_rng.seed = rng.randi()
		total += _play_out(view, playout_rng)
	return total / simulations


func _play_out(view: PublicView, rng: RandomNumberGenerator) -> float:
	var opponent: int = view.opponent()
	var secret_rules: Array[Rule] = [null, null]
	secret_rules[view.viewer] = view.own_secret_rule
	secret_rules[opponent] = _draw_rule(view.decks[opponent].rules, rng)
	var played: Match = Match.resume(view.position, view.decks, secret_rules, rng, view.phase)
	if played == null:
		return 0.0
	var players: Array[AIController] = [null, null]
	players[opponent] = AIController.for_level(AILevel.Level.NORMAL, rng)
	players[view.viewer] = AIController.hard_without_search(rng)
	var model: OpponentModel = AIController.normal_model()
	var holding_back: AIController = AIController.new(rng, GuessPolicy.new(INF), SoftmaxColourPick.new(model), model,
		ExposurePlacement.new(model))
	var first: bool = true
	var commands: int = 0
	while played.phase() != Match.Phase.OVER and commands < MAX_COMMANDS:
		for player: int in played.awaiting_players():
			var deciding: AIController = players[player]
			if player == view.viewer and first:
				deciding = holding_back
				first = false
			var command: Command = deciding.decide(played.public_view(player))
			if command == null or not played.submit(player, command):
				return 0.0
			commands += 1
	var result: MatchResult = played.result()
	if result == null or result.is_draw():
		return 0.0
	return 1.0 if result.winner == view.viewer else -1.0


## A rule drawn with the belief's probabilities.
func _draw_rule(rules: Array[Rule], rng: RandomNumberGenerator) -> Rule:
	var draw: float = rng.randf()
	var last_alive: Rule = null
	for rule: Rule in rules:
		var chance: float = _belief.probability(rule.id)
		if chance <= 0.0:
			continue
		last_alive = rule
		draw -= chance
		if draw <= 0.0:
			return rule
	return last_alive
