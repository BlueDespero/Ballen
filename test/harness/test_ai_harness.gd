extends GutTest

# The AI-vs-AI harness: seeded matches between two AIs with random decks,
# played to the end with no pauses, and the record kept of each.

const Fixtures := preload("res://test/helpers/fixtures.gd")
const ObjectWalker := preload("res://test/helpers/object_walker.gd")


func test_a_record_counts_each_players_turns_and_skips() -> void:
	var book: RuleBook = Fixtures.book()
	var r04: Rule = book.rule("R04")
	var current_match: Match = Fixtures.new_match(book, r04, r04, 11)
	var never_guess: GuessPolicy = GuessPolicy.new(INF)
	var ais: Array[AIController] = [AIController.new(Fixtures.rng(1), never_guess), AIController.new(Fixtures.rng(2), never_guess)]
	assert_true(Harness.play_out(current_match, ais))
	var record: MatchRecord = MatchRecord.from_match(current_match)
	# R04 leaves the 16 inner cells, 8 each; then the players skip in turn,
	# the first player 3 times and the second twice.
	var first: int = current_match.first_player()
	var second: int = Players.opponent(first)
	assert_eq(record.first_player, first)
	assert_eq(record.true_rule_ids, ["R04", "R04"] as Array[String])
	assert_eq(record.turns[first], 11)
	assert_eq(record.skips[first], 3)
	assert_eq(record.turns[second], 10)
	assert_eq(record.skips[second], 2)
	assert_eq(record.result.winner, second)
	assert_eq(record.result.reason, MatchResult.Reason.THIRD_SKIP)


## An AI whose every command is one the match rejects.
class RejectedAI:
	extends AIController

	func decide(_view: PublicView) -> Command:
		return Command.place(Vector2i(-1, -1))


func test_a_rejected_command_leaves_the_match_unfinished() -> void:
	var book: RuleBook = Fixtures.book()
	var current_match: Match = Fixtures.new_match(book, book.rule("R04"), book.rule("R01"), 1)
	var ais: Array[AIController] = [RejectedAI.new(Fixtures.rng(1)), RejectedAI.new(Fixtures.rng(2))]
	assert_false(Harness.play_out(current_match, ais))
	assert_false(MatchRecord.from_match(current_match).is_finished())


func test_a_seeded_run_plays_every_match_to_the_end() -> void:
	var stats: HarnessStats = Harness.run(RuleBook.load_default(), 3, 7)
	assert_eq(stats.matches(), 3)
	assert_eq(stats.finished(), 3)
	assert_gt(stats.average_turns(), 0.0)


func test_the_same_seed_plays_the_same_match() -> void:
	var book: RuleBook = RuleBook.load_default()
	var record: MatchRecord = Harness.play(book, 8)
	assert_true(record.is_finished())
	assert_eq(ObjectWalker.dump(Harness.play(book, 8)), ObjectWalker.dump(record))
