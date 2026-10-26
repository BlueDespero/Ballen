class_name MatchRecord
extends RefCounted

## What the AI-vs-AI harness keeps of one match: who held which true rule,
## who went first, how it ended and how many turns each player played. A
## played turn is one that ended in a placement or a skip. Treat it as an
## immutable value.

## The true rule's id, by player.
var true_rule_ids: Array[String] = []
var first_player: int
## How the match ended; null if it never finished.
var result: MatchResult
## Turns played (placements and skips), by player.
var turns: Array[int] = []
## Turns that ended in a skip, by player.
var skips: Array[int] = []


func _init(p_true_rule_ids: Array[String], p_first_player: int, p_result: MatchResult, p_turns: Array[int], p_skips: Array[int]) -> void:
	true_rule_ids = p_true_rule_ids.duplicate()
	first_player = p_first_player
	result = p_result
	turns = p_turns.duplicate()
	skips = p_skips.duplicate()


func is_finished() -> bool:
	return result != null
