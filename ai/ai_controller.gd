class_name AIController
extends Controller

## The AI player. It sees only the PublicView it is handed (ADR 0002).
##
## It keeps a Belief about the opponent's secret rule (rules the public moves
## rule out, and how likely its OpponentModel finds each remaining one) and
## names the most likely rule once its guess policy fires, which it checks at
## the start of its turn and after it places or skips; on a full board its
## forced guess names the most likely rule. To hide its secret rule it places on a legal
## cell satisfying the most of its own deck rules, ties broken at random. Its
## colour-pick strategy chooses the colour expected to teach it the most.

var _rng: RandomNumberGenerator
var _guess_policy: GuessPolicy
var _colour_pick: ColourPickStrategy
var _belief: Belief
## The same reasoning about the AI's own rules: how exposed its secret rule is.
var _exposure: Belief


## Every random choice goes through rng; seed it for reproducible play.
## guess_policy decides when to guess, colour_pick chooses the opponent's
## colour, and model is how the AI expects the opponent to place. The defaults
## are Normal's (for_level).
func _init(
	rng: RandomNumberGenerator,
	guess_policy: GuessPolicy = DangerGuessPolicy.new(),
	colour_pick: ColourPickStrategy = ColourPickStrategy.new(),
	model: OpponentModel = normal_model(),
) -> void:
	_rng = rng
	_guess_policy = guess_policy
	_colour_pick = colour_pick
	_belief = Belief.new(model)
	_exposure = Belief.new(model, true)


## Normal's model of the player: a careless hider (β 1, lapse 0.2), its
## evidence tempered to 0.4 so its confidence is honest: in AI-vs-AI matches a
## rule it holds 70% likely is right about 70% of the time.
static func normal_model() -> OpponentModel:
	return HiderModel.new(1.0, 0.2, 0.4)


## The AI of a level (AILevel); only built levels can be played.
static func for_level(level: AILevel.Level, rng: RandomNumberGenerator) -> AIController:
	match level:
		AILevel.Level.NORMAL:
			return AIController.new(rng, DangerGuessPolicy.new(), ColourPickStrategy.new(), normal_model())
	push_error("AIController: level %d is not built yet" % level)
	return AIController.new(rng)


func decide(view: PublicView) -> Command:
	_belief.update(view)
	var candidates: Array[Rule] = _belief.alive()
	if view.can_guess():
		_exposure.update(view)
		var guess: Rule = _guess_policy.choose(_belief, _exposure, view, _rng)
		if guess != null:
			return Command.guess(guess.id)
	match view.phase:
		Match.Phase.FIRST_COLOUR, Match.Phase.PICK_COLOUR:
			return Command.pick_colour(_colour_pick.choose(view, _belief, _rng))
		Match.Phase.PLACE:
			var cells: Array[Vector2i] = _best_cells(view)
			if cells.is_empty():
				return null
			return Command.place(_pick(cells))
		Match.Phase.FORCED_GUESS:
			if view.forced_guess_due():
				# The secret rule always remains, so this only guards a view that
				# contradicts itself.
				if candidates.is_empty():
					push_error("AIController: no candidate left for the forced guess")
					return null
				return Command.forced_guess(_belief.top(_rng).id)
	return null


## The legal cells that satisfy the most of the AI's own deck rules, so its
## placements look like any of them could be its secret rule.
func _best_cells(view: PublicView) -> Array[Vector2i]:
	var best: Array[Vector2i] = []
	var best_count: int = -1
	var own_rules: Array[Rule] = view.decks[view.viewer].rules
	for cell: Vector2i in view.own_legal_cells():
		var count: int = 0
		for rule: Rule in own_rules:
			if RuleChecker.is_legal(rule, view.position, view.viewer, view.position.colour, cell):
				count += 1
		if count > best_count:
			best = []
			best_count = count
		if count == best_count:
			best.append(cell)
	return best


func _pick(options: Array) -> Variant:
	return options[_rng.randi_range(0, options.size() - 1)]
