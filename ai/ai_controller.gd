class_name AIController
extends Controller

## The AI player. It sees only the PublicView it is handed (ADR 0002).
##
## It works out the opponent's true rule by ruling out rules (Deduction) and
## names it once its guess policy fires, which it checks at the start of its
## turn and after it places or skips; on a full board its forced guess names a
## random remaining candidate. To hide its true rule it places on a legal
## cell satisfying the most of its own deck rules, ties broken at random. Its
## colour-pick strategy chooses the colour expected to teach it the most.

var _rng: RandomNumberGenerator
var _guess_policy: GuessPolicy
var _colour_pick: ColourPickStrategy


## Every random choice goes through rng; seed it for reproducible play.
## guess_policy decides when to guess; the default guesses when one candidate
## remains. colour_pick chooses the opponent's colour; the default is the
## uniform model.
func _init(
	rng: RandomNumberGenerator,
	guess_policy: GuessPolicy = GuessPolicy.new(),
	colour_pick: ColourPickStrategy = ColourPickStrategy.new(),
) -> void:
	_rng = rng
	_guess_policy = guess_policy
	_colour_pick = colour_pick


func decide(view: PublicView) -> Command:
	var candidates: Array[Rule] = Deduction.candidates(view)
	if view.can_guess():
		var guess: Rule = _guess_policy.choose(candidates)
		if guess != null:
			return Command.guess(guess.id)
	match view.phase:
		Match.Phase.FIRST_COLOUR, Match.Phase.PICK_COLOUR:
			return Command.pick_colour(_colour_pick.choose(view, candidates, _rng))
		Match.Phase.PLACE:
			var cells: Array[Vector2i] = _best_cells(view)
			if cells.is_empty():
				return null
			return Command.place(_pick(cells))
		Match.Phase.FORCED_GUESS:
			if view.forced_guess_due():
				# The true rule always remains, so this only guards a view that
				# contradicts itself.
				if candidates.is_empty():
					push_error("AIController: no candidate left for the forced guess")
					return null
				return Command.forced_guess(_pick(candidates).id)
	return null


## The legal cells that satisfy the most of the AI's own deck rules, so its
## placements look like any of them could be its true rule.
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
