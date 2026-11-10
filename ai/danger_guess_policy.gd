class_name DangerGuessPolicy
extends GuessPolicy

## Normal's guessing: wait for near-certainty while the AI's own rule is well
## hidden, and settle for less the closer the opponent is to naming it. The
## threshold slides from SAFE to DESPERATE with danger(): how likely an
## opponent reading the AI's public moves the way the AI reads theirs would
## find the AI's secret rule (its exposure), or full danger once the AI has
## skipped all but its last allowed time (a colour it can't place would lose
## the match).

const SAFE: float = 0.95
const DESPERATE: float = 0.35


func _init() -> void:
	super(SAFE)


func threshold(view: PublicView, exposure: Belief) -> float:
	return lerpf(SAFE, DESPERATE, danger(view, exposure))


## 0 while the AI's secret rule looks no likelier than at the start (1 in 5),
## rising to 1 as the opponent could become as sure of it as SAFE.
static func danger(view: PublicView, exposure: Belief) -> float:
	if view.position.skips[view.viewer] >= Match.LOSING_SKIP - 1:
		return 1.0
	var start: float = 1.0 / Deck.SIZE
	var seen: float = exposure.probability(view.own_secret_rule.id)
	return clampf((seen - start) / (SAFE - start), 0.0, 1.0)
