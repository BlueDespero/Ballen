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
	var playout: Playout = start(view, rng, first_cell)
	playout.run(0)
	return playout.value


## A playout ready to run (see play), so it can be run in slices.
func start(view: PublicView, rng: RandomNumberGenerator, first_cell: Vector2i = PlacementStrategy.NO_CELL) -> Playout:
	var opponent: int = view.opponent()
	var secret_rules: Array[Rule] = [null, null]
	secret_rules[view.viewer] = view.own_secret_rule
	secret_rules[opponent] = draw_rule(view.decks[opponent].rules, rng)
	return Playout.new(view, secret_rules, rng, first_cell)


## One match played on from a view, a command at a time.
class Playout:
	## The result for the AI once finished: 1 win, −1 loss, 0 draw.
	var value: float = 0.0
	var finished: bool = false
	var _viewer: int
	var _played: Match
	var _players: Array[AIController] = [null, null]
	var _holding_back: AIController = null
	var _commands: int = 0

	func _init(view: PublicView, secret_rules: Array[Rule], rng: RandomNumberGenerator, first_cell: Vector2i) -> void:
		_viewer = view.viewer
		_played = Match.resume(view.position, view.decks, secret_rules, rng, view.phase)
		if _played == null:
			finished = true
			return
		_players[view.opponent()] = AIController.for_level(AILevel.Level.NORMAL, rng)
		_players[_viewer] = AIController.hard_without_search(rng)
		if first_cell != PlacementStrategy.NO_CELL:
			if not _played.submit(_viewer, Command.place(first_cell)):
				push_error("Playouts: %s is not a legal first placement" % first_cell)
				finished = true
		else:
			var model: OpponentModel = AIController.normal_model()
			_holding_back = AIController.new(rng, GuessPolicy.new(INF), SoftmaxColourPick.new(model), model,
				ExposurePlacement.new(model))

	## Plays on, at least one command, until the match ends or about
	## deadline_msec (Time.get_ticks_msec(); 0 for no limit). True once finished.
	func run(deadline_msec: int) -> bool:
		var this_run: int = 0
		while not finished:
			if this_run > 0 and deadline_msec > 0 and Time.get_ticks_msec() >= deadline_msec:
				return false
			_step()
			this_run += 1
		return true

	func _step() -> void:
		if _played.phase() == Match.Phase.OVER or _commands >= MAX_COMMANDS:
			_finish()
			return
		var player: int = _played.awaiting_players()[0]
		var deciding: AIController = _players[player]
		if player == _viewer and _holding_back != null:
			deciding = _holding_back
			_holding_back = null
		var command: Command = deciding.decide(_played.public_view(player))
		if command == null or not _played.submit(player, command):
			finished = true
			return
		_commands += 1
		if _played.phase() == Match.Phase.OVER:
			_finish()

	func _finish() -> void:
		finished = true
		var result: MatchResult = _played.result()
		if result != null and not result.is_draw():
			value = 1.0 if result.winner == _viewer else -1.0


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
