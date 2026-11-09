class_name AIController
extends Controller

## The AI player. It sees only the PublicView it is handed (ADR 0002).
##
## It keeps a Belief about the opponent's secret rule (rules the public moves
## rule out, and how likely its OpponentModel finds each remaining one) and
## names the most likely rule once its guess policy fires, which it checks at
## the start of its turn and after it places or skips; on a full board its
## forced guess names the most likely rule. Its placement strategy chooses
## where it places its own ball, so its secret rule stays hidden, and its
## colour-pick strategy the colour expected to teach it the most. It also keeps
## the same belief about its own rules (its exposure).

var _rng: RandomNumberGenerator
var _guess_policy: GuessPolicy
var _colour_pick: ColourPickStrategy
var _placement: PlacementStrategy
var _belief: Belief
## The same reasoning about the AI's own rules: how exposed its secret rule is.
var _exposure: Belief


## Every random choice goes through rng; seed it for reproducible play.
## guess_policy decides when to guess, colour_pick chooses the opponent's
## colour, model is how the AI expects the opponent to place, and placement
## where it places its own ball. The defaults are Normal's (for_level).
func _init(
	rng: RandomNumberGenerator,
	guess_policy: GuessPolicy = DangerGuessPolicy.new(),
	colour_pick: ColourPickStrategy = InformationColourPick.new(normal_model()),
	model: OpponentModel = normal_model(),
	placement: PlacementStrategy = PlacementStrategy.new(),
) -> void:
	_rng = rng
	_guess_policy = guess_policy
	_colour_pick = colour_pick
	_placement = placement
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
			return AIController.new(rng, DangerGuessPolicy.new(), InformationColourPick.new(normal_model()), normal_model(),
				HidingPlacement.new())
	push_error("AIController: level %d is not built yet" % level)
	return AIController.new(rng)


func decide(view: PublicView) -> Command:
	_belief.update(view)
	_exposure.update(view)
	var candidates: Array[Rule] = _belief.alive()
	if view.can_guess():
		var guess: Rule = _guess_policy.choose(_belief, _exposure, view, _rng)
		if guess != null:
			return Command.guess(guess.id)
	match view.phase:
		Match.Phase.FIRST_COLOUR, Match.Phase.PICK_COLOUR:
			return Command.pick_colour(_colour_pick.choose(view, _belief, _rng))
		Match.Phase.PLACE:
			var cell: Vector2i = _placement.choose(view, _exposure, _rng)
			if cell == PlacementStrategy.NO_CELL:
				return null
			return Command.place(cell)
		Match.Phase.FORCED_GUESS:
			if view.forced_guess_due():
				# The secret rule always remains, so this only guards a view that
				# contradicts itself.
				if candidates.is_empty():
					push_error("AIController: no candidate left for the forced guess")
					return null
				return Command.forced_guess(_belief.top(_rng).id)
	return null


