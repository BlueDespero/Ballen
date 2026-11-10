class_name LooseColourPick
extends ColourPickStrategy

## Easy's colour pick: sometimes the considered pick (the base strategy's), the
## rest of the time any colour. A player still sees it try, now and then, to
## hand them a colour that splits their rules.

## The chance of the considered pick.
var focus: float = 0.4


func _init(p_focus: float = 0.4) -> void:
	focus = p_focus


func choose(view: PublicView, belief: Belief, rng: RandomNumberGenerator) -> String:
	if rng.randf() < focus:
		return super(view, belief, rng)
	last_closeness = 0.0
	return BallColour.ALL[rng.randi_range(0, BallColour.ALL.size() - 1)]
