class_name AIController
extends Controller

## The AI player. It sees only the PublicView it is handed (ADR 0002).
##
## It works out the opponent's true rule by hard elimination (Deduction) and
## names it once its guess policy fires, which it checks at the start of its
## turn and after it places or skips; on a full board its forced guess names a
## random remaining candidate. Otherwise it places on a random legal cell and
## picks a random colour: placement preference and the colour-pick strategy
## replace these choices in later tickets.

var _rng: RandomNumberGenerator
var _guess_policy: GuessPolicy


## Every random choice goes through rng; seed it for reproducible play.
## guess_policy decides when to guess; the default guesses when one candidate
## remains.
func _init(rng: RandomNumberGenerator, guess_policy: GuessPolicy = GuessPolicy.new()) -> void:
	_rng = rng
	_guess_policy = guess_policy


func decide(view: PublicView) -> Command:
	if view.can_guess():
		var guess: Rule = _guess_policy.choose(Deduction.candidates(view))
		if guess != null:
			return Command.guess(guess.id)
	match view.phase:
		Match.Phase.FIRST_COLOUR, Match.Phase.PICK_COLOUR:
			return Command.pick_colour(_pick(BallColour.ALL))
		Match.Phase.PLACE:
			var cells: Array[Vector2i] = view.own_legal_cells()
			if cells.is_empty():
				return null
			return Command.place(_pick(cells))
		Match.Phase.FORCED_GUESS:
			if view.forced_guess_due():
				return Command.forced_guess(_pick(Deduction.candidates(view)).id)
	return null


func _pick(options: Array) -> Variant:
	return options[_rng.randi_range(0, options.size() - 1)]
