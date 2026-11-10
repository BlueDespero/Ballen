class_name ValueGuessPolicy
extends GuessPolicy

## Hard's guessing, on expected value (docs/ai-decision-theory-research.md,
## "Guess when confidence beats the value of waiting"). With a win worth +1, a
## loss −1 and a draw 0, guessing now is worth 2p − 1 for the top rule's
## probability p, and the AI guesses once that beats the value of waiting:
## p ≥ (1 + V_wait) / 2, with no floor on p.
##
## V_wait looks one opponent turn ahead, from the exposure belief (how an
## opponent reading the AI as it reads them sees its rules):
## - the opponent guesses next turn with chance g, rising from 0 at DESPERATE
##   to 1 at SAFE as their top rule's probability does (Normal's range);
##   they name the AI's rule with chance g × exposure(own rule) (the AI loses),
##   and some other rule with chance g × (1 − exposure(own rule)) (it wins);
## - one skip from losing, the opponent can end the match with a colour the AI
##   has no cell for, counted as a guess they make for sure;
## - otherwise the match goes on, and the AI will be at least as sure: its top
##   rule's odds grow by ODDS_PER_TURN, worth max(0, 2p' − 1) then.

const SAFE: float = 0.95
const DESPERATE: float = 0.35
## How much one more opponent turn multiplies the top rule's odds, on average.
const ODDS_PER_TURN: float = 1.6

## How much one more opponent turn multiplies the top rule's odds here.
var odds_per_turn: float = ODDS_PER_TURN
## The top rule's probability at the last choose(), for threshold().
var _last_top: float = 0.0


func _init() -> void:
	super(SAFE)


func threshold(view: PublicView, exposure: Belief) -> float:
	return (1.0 + value_of_waiting(view, exposure, _last_top, odds_per_turn)) / 2.0


## Records the top probability so threshold() can look one turn ahead from it.
func choose(belief: Belief, exposure: Belief, view: PublicView, rng: RandomNumberGenerator) -> Rule:
	var top: Rule = belief.top(rng)
	_last_top = belief.probability(top.id) if top != null else 0.0
	return super(belief, exposure, view, rng)


## The expected value of not guessing now, −1 to 1.
static func value_of_waiting(view: PublicView, exposure: Belief, top: float, odds_gain: float = ODDS_PER_TURN) -> float:
	var seen: Dictionary[String, float] = exposure.probabilities()
	var mine: float = seen.get(view.own_secret_rule.id, 0.0)
	var their_top: float = 0.0
	for chance: float in seen.values():
		their_top = maxf(their_top, chance)
	var they_guess: float = clampf((their_top - DESPERATE) / (SAFE - DESPERATE), 0.0, 1.0)
	if view.position.skips[view.viewer] >= Match.LOSING_SKIP - 1:
		they_guess = 1.0
		mine = maxf(mine, 0.5)
	var lose: float = they_guess * mine
	var win: float = they_guess * (1.0 - mine)
	var odds: float = top / maxf(1.0 - top, 1e-9) * odds_gain
	var later: float = maxf(0.0, 2.0 * odds / (1.0 + odds) - 1.0)
	return -lose + win + (1.0 - lose - win) * later
