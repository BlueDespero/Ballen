class_name HarnessStats
extends RefCounted

## The balance numbers of an AI-vs-AI harness run, built from its match
## records. A match that never finished counts only in matches(); every other
## number is over finished matches.

var _matches: int = 0
var _finished: Array[MatchRecord] = []


func add(record: MatchRecord) -> void:
	_matches += 1
	if record.is_finished():
		_finished.append(record)


func matches() -> int:
	return _matches


func finished() -> int:
	return _finished.size()


func first_player_wins() -> int:
	return _count(_finished, func(record: MatchRecord) -> bool:
		return record.result.winner == record.first_player)


func first_player_losses() -> int:
	return _count(_finished, func(record: MatchRecord) -> bool:
		return record.result.winner == Players.opponent(record.first_player))


func draws() -> int:
	return _count(_finished, func(record: MatchRecord) -> bool:
		return record.result.is_draw())


## Finished matches that ended for this reason.
func ended_by(reason: MatchResult.Reason) -> int:
	return _count(_finished, func(record: MatchRecord) -> bool:
		return record.result.reason == reason)


## Turns played per finished match, both players' turns counted.
func average_turns() -> float:
	if _finished.is_empty():
		return 0.0
	var total: int = 0
	for record: MatchRecord in _finished:
		for player: int in Players.COUNT:
			total += record.turns[player]
	return float(total) / _finished.size()


## The ids of every rule that was a true rule in a finished match, sorted.
func true_rule_ids() -> Array[String]:
	var ids: Array[String] = []
	for record: MatchRecord in _finished:
		for rule_id: String in record.true_rule_ids:
			if not ids.has(rule_id):
				ids.append(rule_id)
	ids.sort()
	return ids


## How many times a player held this rule as their true rule. A match where
## both players held it counts twice.
func holders(rule_id: String) -> int:
	return _holdings(rule_id).size()


## Turns ending in a skip ÷ all turns played by holders of this true rule; 0
## if it was never held or its holders played no turn.
func skip_rate(rule_id: String) -> float:
	var skips: int = 0
	var turns: int = 0
	for holding: Array in _holdings(rule_id):
		var record: MatchRecord = holding[0]
		var player: int = holding[1]
		skips += record.skips[player]
		turns += record.turns[player]
	if turns == 0:
		return 0.0
	return float(skips) / turns


## Matches won by a holder of this true rule.
func wins(rule_id: String) -> int:
	return _count(_holdings(rule_id), func(holding: Array) -> bool:
		var record: MatchRecord = holding[0]
		return record.result.winner == holding[1])


## Draws a holder of this true rule played.
func draws_held(rule_id: String) -> int:
	return _count(_holdings(rule_id), func(holding: Array) -> bool:
		var record: MatchRecord = holding[0]
		return record.result.is_draw())


## Wins ÷ holdings of this true rule (a draw is not a win); 0 if never held.
func win_rate(rule_id: String) -> float:
	var held: int = holders(rule_id)
	if held == 0:
		return 0.0
	return float(wins(rule_id)) / held


## Every number as text, one true rule per row of the table.
func summary() -> String:
	var lines: Array[String] = [
		"Matches finished: %d / %d" % [finished(), matches()],
		"First player wins / losses / draws: %d / %d / %d" % [first_player_wins(), first_player_losses(), draws()],
		"Ended by: right guess %d, wrong guess %d, third skip %d, forced guesses %d" % [
			ended_by(MatchResult.Reason.RIGHT_GUESS),
			ended_by(MatchResult.Reason.WRONG_GUESS),
			ended_by(MatchResult.Reason.THIRD_SKIP),
			ended_by(MatchResult.Reason.FORCED_GUESSES),
		],
		"Average turns per match (both players): %.1f" % average_turns(),
		"",
		"True rule  Held  Skip rate  Win rate  W / L / D",
	]
	for rule_id: String in true_rule_ids():
		var held: int = holders(rule_id)
		var won: int = wins(rule_id)
		var drawn: int = draws_held(rule_id)
		lines.append("%-9s  %4d  %8.1f%%  %7.1f%%  %d / %d / %d" % [
			rule_id, held, skip_rate(rule_id) * 100.0, win_rate(rule_id) * 100.0, won, held - won - drawn, drawn,
		])
	return "\n".join(lines) + "\n"


## How many items pass test, a func(item) -> bool.
func _count(items: Array, test: Callable) -> int:
	var count: int = 0
	for item: Variant in items:
		if test.call(item):
			count += 1
	return count


## Each [record, player] where that player held the rule as their true rule.
func _holdings(rule_id: String) -> Array[Array]:
	var holdings: Array[Array] = []
	for record: MatchRecord in _finished:
		for player: int in Players.COUNT:
			if record.true_rule_ids[player] == rule_id:
				holdings.append([record, player])
	return holdings
