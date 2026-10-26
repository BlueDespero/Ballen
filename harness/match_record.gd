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


## The record of a match as it stands (its result is null while it runs),
## turns counted from its history. The true rules are read from each
## player's own view.
static func from_match(game: Match) -> MatchRecord:
	var ids: Array[String] = []
	var turns_played: Array[int] = []
	var skipped: Array[int] = []
	for player: int in Players.COUNT:
		ids.append(game.public_view(player).own_true_rule.id)
		turns_played.append(0)
		skipped.append(0)
	for entry: HistoryEntry in game.history():
		match entry.type:
			HistoryEntry.Type.PLACEMENT:
				turns_played[entry.player] += 1
			HistoryEntry.Type.SKIP:
				turns_played[entry.player] += 1
				skipped[entry.player] += 1
	return MatchRecord.new(ids, game.first_player(), game.result(), turns_played, skipped)


func is_finished() -> bool:
	return result != null
