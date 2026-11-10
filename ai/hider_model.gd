class_name HiderModel
extends OpponentModel

## An opponent who hides: they favour cells that many of their 5 deck rules
## allow, since a cell every rule allows gives nothing away. Weight e^(β·k) for
## a cell k of their deck rules allow. A low β is a careless hider (Normal's
## model of the player); a high one a deliberate hider.

## How strongly the opponent prefers cells more of their rules allow.
var beta: float = 1.0


func _init(p_beta: float = 1.0, p_lapse: float = 0.2, p_temper: float = 1.0) -> void:
	beta = p_beta
	lapse = p_lapse
	temper = p_temper


func weights(legal_by_rule: Dictionary[String, Array]) -> Dictionary[Vector2i, float]:
	var shared_by: Dictionary[Vector2i, int] = {}
	for rule_id: String in legal_by_rule:
		for cell: Vector2i in legal_by_rule[rule_id]:
			shared_by[cell] = shared_by.get(cell, 0) + 1
	var cell_weights: Dictionary[Vector2i, float] = {}
	for cell: Vector2i in shared_by:
		cell_weights[cell] = exp(beta * shared_by[cell])
	return cell_weights
