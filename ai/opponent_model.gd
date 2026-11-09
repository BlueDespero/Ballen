class_name OpponentModel
extends RefCounted

## How the AI expects the opponent to choose a cell among those their secret
## rule allows: the soft half of its Belief (the hard half, which rules a
## placement or skip makes impossible, is certain and never comes from a
## model). Levels differ in their model of the player, never in what they see.
##
## This base model is the uniform one: the opponent places at random among
## their legal cells, so a placement favours rules that allow fewer cells (the
## size principle). Subclasses weight the cells (HiderModel).

## The share of each likelihood spread evenly over the legal cells, whatever
## the weights say, so a soft model never all but rules out a rule the hard
## evidence keeps. Unused by the uniform model, which is even already.
var lapse: float = 0.0
## How much each placement's soft evidence counts, 0 to 1: the belief adds
## temper × log(likelihood). Below 1 the AI trusts its model of the player less,
## which keeps its confidence honest (calibrated with the harness) and, lower
## still, makes it learn slowly.
var temper: float = 1.0


## A weight per cell for one opponent placement; cells it leaves out weigh 1.
## legal_by_rule holds the cells each rule of the opponent's deck allowed for
## the placement's colour, by rule id, judged on the position just before it.
func weights(_legal_by_rule: Dictionary[String, Array]) -> Dictionary[Vector2i, float]:
	var even: Dictionary[Vector2i, float] = {}
	return even


## The chance the opponent placed on cell if their secret rule allowed exactly
## legal (which holds cell), given the weights for that placement.
func likelihood(cell: Vector2i, legal: Array, cell_weights: Dictionary[Vector2i, float]) -> float:
	var total: float = 0.0
	for legal_cell: Vector2i in legal:
		total += cell_weights.get(legal_cell, 1.0)
	var chosen: float = cell_weights.get(cell, 1.0) / total
	return (1.0 - lapse) * chosen + lapse / legal.size()
