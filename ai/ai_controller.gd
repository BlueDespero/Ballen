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

## Thinking pauses (pause_seconds), in seconds: the shortest, the longest
## for a routine colour pick or placement, and the longest of all, for a
## guess the AI only just made or only just held back.
const SHORTEST_PAUSE: float = 0.5
const ROUTINE_PAUSE: float = 2.5
const LONGEST_PAUSE: float = 5.0
## A placement is routine: this far from SHORTEST_PAUSE toward ROUTINE_PAUSE.
const PLACEMENT_CLOSENESS: float = 0.2
## Easy guesses only once its belief reaches this, whatever the danger.
const EASY_THRESHOLD: float = 0.95
## Natural variation of a pause, either way, in seconds.
const PAUSE_WOBBLE: float = 0.15
## Hard's playouts: per guess decision, and per placement the best hiding
## cells tried and the playouts of each (the 1000-match gate run's settings).
const HARD_GUESS_PLAYOUTS: int = 32
const HARD_PLACEMENT_CANDIDATES: int = 4
const HARD_PLACEMENT_PLAYOUTS: int = 8
## How long Hard may think about one decision in the scene, in milliseconds
## (GDD: up to 5 s a choice): the guess and the placement each get this long.
## In Chrome a decision takes about 2 s on average with no limit.
const HARD_THINK_LIMIT_MSEC: int = 2500

var _rng: RandomNumberGenerator
var _guess_policy: GuessPolicy
var _colour_pick: ColourPickStrategy
var _placement: PlacementStrategy
var _belief: Belief
## The same reasoning about the AI's own rules: how exposed its secret rule is.
var _exposure: Belief
## How close the last decision was, for its pause: the action's closeness and,
## if the AI weighed a guess, the guess's.
var _action_closeness: float = 0.0
var _guess_closeness: float = -1.0
## Thinking in steps (Hard): whether the scene spreads decisions over frames,
## whether one is unfinished, whether its guess has been weighed already, and
## how long it has taken so far.
var _thinks_in_steps: bool = false
var _thinking: bool = false
var _guess_weighed: bool = false
var _thought_msec: int = 0
## When the decision started and when its guess was weighed (-1 before), by
## the wall clock: the thinking limits count the frames in between too.
var _decision_started: int = 0
var _guess_done_at: int = -1
## In the scene, how long a decision may think before it settles for what it
## has (0: no limit, as in the harness, so a seeded match always plays the same).
var think_limit_msec: int = 0


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


## Easy's model of the player: they place at random among their legal cells,
## and each placement counts for little (temper 0.15), so it learns slowly.
static func easy_model() -> OpponentModel:
	var model: OpponentModel = OpponentModel.new()
	model.temper = 0.15
	return model


## The AI of a level (AILevel); only built levels can be played.
static func for_level(level: AILevel.Level, rng: RandomNumberGenerator) -> AIController:
	match level:
		AILevel.Level.EASY:
			return AIController.new(rng, GuessPolicy.new(EASY_THRESHOLD), LooseColourPick.new(), easy_model(),
				AnyLegalPlacement.new())
		AILevel.Level.HARD:
			var hard: AIController = AIController.new(rng, RolloutGuessPolicy.new(HARD_GUESS_PLAYOUTS),
				SoftmaxColourPick.new(normal_model()), normal_model(),
				RolloutPlacement.new(HARD_PLACEMENT_CANDIDATES, HARD_PLACEMENT_PLAYOUTS))
			hard._thinks_in_steps = true
			return hard
		AILevel.Level.NORMAL:
			return AIController.new(rng, DangerGuessPolicy.new(), InformationColourPick.new(normal_model()), normal_model(),
				HidingPlacement.new())
	push_error("AIController: level %d is not built yet" % level)
	return AIController.new(rng)


## Hard's one-step pieces: expected-value guessing, softmax colours, exposure
## placement. Hard plays its own future moves like this in its playouts
## (Playouts), which keeps them quick.
static func hard_without_search(rng: RandomNumberGenerator) -> AIController:
	return AIController.new(rng, ValueGuessPolicy.new(), SoftmaxColourPick.new(normal_model()), normal_model(),
		ExposurePlacement.new(normal_model()))


## Longer the closer the last decision was, so a long pause honestly means the
## AI was unsure (GDD, "Thinking time"): up to ROUTINE_PAUSE for a colour pick
## or placement, up to LONGEST_PAUSE when it weighed a guess near its threshold.
## A small wobble keeps equal pauses from looking mechanical.
func pause_seconds(rng: RandomNumberGenerator) -> float:
	var seconds: float = lerpf(SHORTEST_PAUSE, ROUTINE_PAUSE, _action_closeness)
	if _guess_closeness >= 0.0:
		seconds = maxf(seconds, lerpf(SHORTEST_PAUSE, LONGEST_PAUSE, _guess_closeness))
	seconds += rng.randf_range(-PAUSE_WOBBLE, PAUSE_WOBBLE)
	if _thinks_in_steps:
		# Its thinking already took a while: only the rest of the pause.
		return clampf(seconds - _thought_msec / 1000.0, 0.0, LONGEST_PAUSE)
	return clampf(seconds, SHORTEST_PAUSE, LONGEST_PAUSE)


func decide(view: PublicView) -> Command:
	return think_step(view, 0)


func thinks_in_steps() -> bool:
	return _thinks_in_steps


func is_thinking() -> bool:
	return _thinking


## decide() in slices: works until about deadline_msec (0: no limit) and
## returns null with is_thinking() true if its guess policy or placement
## stopped there; called again with the same view, it carries on where it
## stopped. Seeded, it decides exactly as decide() does.
func think_step(view: PublicView, deadline_msec: int) -> Command:
	var started: int = Time.get_ticks_msec()
	if not _thinking:
		_decision_started = started
		_guess_done_at = -1
		_belief.update(view)
		_exposure.update(view)
		_action_closeness = 0.0
		_guess_closeness = -1.0
		_thought_msec = 0
		_guess_weighed = false
	_guess_policy.deadline_msec = deadline_msec
	_placement.deadline_msec = deadline_msec
	# Each of the two choices (whether to guess, then where to place) gets its
	# own thinking limit, by the wall clock.
	var placement_started: int = _guess_done_at if _guess_done_at >= 0 else _decision_started
	_guess_policy.must_finish = think_limit_msec > 0 and started - _decision_started >= think_limit_msec
	_placement.must_finish = think_limit_msec > 0 and started - placement_started >= think_limit_msec
	var command: Command = _decide(view)
	_thinking = _guess_policy.is_pending() or _placement.is_pending()
	_thought_msec = Time.get_ticks_msec() - _decision_started
	return null if _thinking else command


func _decide(view: PublicView) -> Command:
	if view.can_guess() and not _guess_weighed:
		var guess: Rule = _guess_policy.choose(_belief, _exposure, view, _rng)
		if _guess_policy.is_pending():
			return null
		_guess_weighed = true
		_guess_done_at = Time.get_ticks_msec()
		_guess_closeness = _guess_policy.last_closeness
		if guess != null:
			return Command.guess(guess.id)
	match view.phase:
		Match.Phase.FIRST_COLOUR, Match.Phase.PICK_COLOUR:
			var colour: String = _colour_pick.choose(view, _belief, _rng)
			_action_closeness = _colour_pick.last_closeness
			return Command.pick_colour(colour)
		Match.Phase.PLACE:
			_action_closeness = PLACEMENT_CLOSENESS
			var cell: Vector2i = _placement.choose(view, _exposure, _rng)
			if _placement.is_pending() or cell == PlacementStrategy.NO_CELL:
				return null
			return Command.place(cell)
		Match.Phase.FORCED_GUESS:
			if view.forced_guess_due():
				# The secret rule always remains, so this only guards a view that
				# contradicts itself.
				if _belief.alive().is_empty():
					push_error("AIController: no candidate left for the forced guess")
					return null
				return Command.forced_guess(_belief.top(_rng).id)
	return null
