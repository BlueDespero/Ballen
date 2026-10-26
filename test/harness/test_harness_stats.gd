extends GutTest

# The harness statistics: match records in, balance numbers out. Records are
# built by hand so every expected number is worked out from the spec.


## A finished match record. turns and skips are by player; winner NONE is a draw.
func _record(true_rule_ids: Array[String], first_player: int, winner: int, turns: Array[int], skips: Array[int]) -> MatchRecord:
	var result: MatchResult = MatchResult.new(winner, MatchResult.Reason.RIGHT_GUESS)
	return MatchRecord.new(true_rule_ids, first_player, result, turns, skips)


func _unfinished(true_rule_ids: Array[String], turns: Array[int], skips: Array[int]) -> MatchRecord:
	return MatchRecord.new(true_rule_ids, 0, null, turns, skips)


func test_no_matches_give_zeroes() -> void:
	var stats: HarnessStats = HarnessStats.new()
	assert_eq(stats.matches(), 0)
	assert_eq(stats.finished(), 0)
	assert_eq(stats.average_turns(), 0.0)


func test_counts_finished_matches_and_results_for_the_first_player() -> void:
	var stats: HarnessStats = HarnessStats.new()
	stats.add(_record(["R01", "R04"], 0, 0, [5, 5], [0, 0]))
	stats.add(_record(["R01", "R04"], 1, 1, [5, 5], [0, 0]))
	stats.add(_record(["R01", "R04"], 1, 0, [5, 5], [0, 0]))
	stats.add(_record(["R01", "R04"], 0, Players.NONE, [18, 18], [0, 0]))
	stats.add(_unfinished(["R01", "R04"], [3, 3], [0, 0]))
	assert_eq(stats.matches(), 5)
	assert_eq(stats.finished(), 4)
	assert_eq(stats.first_player_wins(), 2)
	assert_eq(stats.first_player_losses(), 1)
	assert_eq(stats.draws(), 1)


func test_average_turns_count_both_players_over_finished_matches() -> void:
	var stats: HarnessStats = HarnessStats.new()
	stats.add(_record(["R01", "R04"], 0, 0, [6, 5], [0, 0]))
	stats.add(_record(["R01", "R04"], 1, 1, [10, 9], [2, 1]))
	stats.add(_unfinished(["R01", "R04"], [40, 40], [0, 0]))
	assert_eq(stats.average_turns(), 15.0, "(11 + 19) / 2")


func test_skip_rate_of_a_rule_is_over_the_turns_of_its_holders() -> void:
	var stats: HarnessStats = HarnessStats.new()
	stats.add(_record(["R04", "R01"], 0, 1, [10, 9], [2, 0]))
	stats.add(_record(["R04", "R04"], 1, 0, [8, 7], [1, 0]))
	stats.add(_record(["R18", "R10"], 0, 0, [5, 5], [1, 1]))
	assert_almost_eq(stats.skip_rate("R04"), 0.12, 1e-9, "(2 + 1 + 0) / (10 + 8 + 7), both holders in the second match")
	assert_eq(stats.skip_rate("R01"), 0.0, "R01's holder never skipped")
	assert_eq(stats.true_rule_ids(), ["R01", "R04", "R10", "R18"] as Array[String])


func test_a_rule_never_held_has_no_skip_rate() -> void:
	var stats: HarnessStats = HarnessStats.new()
	stats.add(_record(["R04", "R01"], 0, 1, [10, 9], [2, 0]))
	assert_eq(stats.holders("R07"), 0)
	assert_eq(stats.skip_rate("R07"), 0.0)


func test_win_rate_of_a_true_rule_is_its_holders_wins_over_its_holdings() -> void:
	var stats: HarnessStats = HarnessStats.new()
	stats.add(_record(["R04", "R01"], 0, 1, [10, 9], [0, 0]))
	stats.add(_record(["R04", "R04"], 1, 0, [8, 7], [0, 0]))
	stats.add(_record(["R04", "R10"], 0, Players.NONE, [18, 18], [0, 0]))
	assert_eq(stats.holders("R04"), 4)
	assert_eq(stats.wins("R04"), 1, "only player 0 in the second match")
	assert_eq(stats.draws_held("R04"), 1)
	assert_eq(stats.win_rate("R04"), 0.25, "a draw is not a win")
	assert_eq(stats.win_rate("R01"), 1.0)
	assert_eq(stats.win_rate("R07"), 0.0, "never held")


func test_counts_how_finished_matches_ended() -> void:
	var stats: HarnessStats = HarnessStats.new()
	stats.add(_record(["R04", "R01"], 0, 1, [10, 9], [0, 0]))
	stats.add(MatchRecord.new(["R04", "R01"] as Array[String], 0, MatchResult.new(1, MatchResult.Reason.THIRD_SKIP), [12, 11], [3, 2]))
	stats.add(_record(["R04", "R01"], 0, 0, [10, 9], [0, 0]))
	assert_eq(stats.ended_by(MatchResult.Reason.RIGHT_GUESS), 2)
	assert_eq(stats.ended_by(MatchResult.Reason.THIRD_SKIP), 1)
	assert_eq(stats.ended_by(MatchResult.Reason.FORCED_GUESSES), 0)
