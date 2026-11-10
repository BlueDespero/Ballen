class_name Playouts
extends RefCounted

## Plays a match on to the end from the AI's view, for Hard's playout-based
## choices (RolloutGuessPolicy, RolloutPlacement; DMU §4.6, Monte Carlo
## evaluation). The opponent's secret rule is drawn from a tempered belief;
## the opponent plays as Normal and the AI as Hard's one-step pieces.
##
## The belief is tempered more than the AI's usual one (0.1, not 0.4): that
## one is overconfident against a player who hides (docs/ai-internals.md,
## "Calibration"), and drawing from it makes guessing look better than it is.

## More commands than any playout needs; one still running is counted a draw.
const MAX_COMMANDS: int = 500

## The belief the opponent's rule is drawn from; update() it before playing.
var belief: Belief


func _init(temper: float = 0.1) -> void:
	belief = Belief.new(HiderModel.new(1.0, 0.2, temper))


## Brings the belief up to the view.
func update(view: PublicView) -> void:
	belief.update(view)


## One playout from the view; the result for the AI: 1 win, −1 loss, 0 draw.
## With a cell, the AI first places there (the view must await its
## placement); without, it first acts without guessing.
func play(view: PublicView, rng: RandomNumberGenerator, first_cell: Vector2i = PlacementStrategy.NO_CELL) -> float:
	var opponent: int = view.opponent()
	var secret_rules: Array[Rule] = [null, null]
	secret_rules[view.viewer] = view.own_secret_rule
	secret_rules[opponent] = draw_rule(view.decks[opponent].rules, rng)
	var played: Match = Match.resume(view.position, view.decks, secret_rules, rng, view.phase)
	if played == null:
		return 0.0
	var players: Array[AIController] = [null, null]
	players[opponent] = AIController.for_level(AILevel.Level.NORMAL, rng)
	players[view.viewer] = AIController.hard_without_search(rng)
	var holding_back: AIController = null
	if first_cell != PlacementStrategy.NO_CELL:
		if not played.submit(view.viewer, Command.place(first_cell)):
			push_error("Playouts: %s is not a legal first placement" % first_cell)
			return 0.0
	else:
		var model: OpponentModel = AIController.normal_model()
		holding_back = AIController.new(rng, GuessPolicy.new(INF), SoftmaxColourPick.new(model), model,
			ExposurePlacement.new(model))
	var commands: int = 0
	while played.phase() != Match.Phase.OVER and commands < MAX_COMMANDS:
		for player: int in played.awaiting_players():
			var deciding: AIController = players[player]
			if player == view.viewer and holding_back != null:
				deciding = holding_back
				holding_back = null
			var command: Command = deciding.decide(played.public_view(player))
			if command == null or not played.submit(player, command):
				return 0.0
			commands += 1
	var result: MatchResult = played.result()
	if result == null or result.is_draw():
		return 0.0
	return 1.0 if result.winner == view.viewer else -1.0


## A rule drawn with the belief's probabilities.
func draw_rule(rules: Array[Rule], rng: RandomNumberGenerator) -> Rule:
	var draw: float = rng.randf()
	var last_alive: Rule = null
	for rule: Rule in rules:
		var chance: float = belief.probability(rule.id)
		if chance <= 0.0:
			continue
		last_alive = rule
		draw -= chance
		if draw <= 0.0:
			return rule
	return last_alive
