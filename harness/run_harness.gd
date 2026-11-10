extends SceneTree

## Command-line entry point of the AI-vs-AI harness. From the repo root:
##     godot --headless --path . -s harness/run_harness.gd -- --matches 100 --seed 1
## Plays the matches with no pauses and prints the summary. Exit code 0 when
## every match finished, 1 otherwise (or on a bad argument).
##
## --start N plays matches N onwards (default 0), so a long run can be split
## into parts run at once: --start 0 --matches 250 and --start 250 --matches 250
## play the same matches as one run of 500.
##
## --levels A,B pits two AI levels (easy, normal, hard) against each other, the
## seats swapped every other match; the default is normal,normal. --gate S
## also fails the run (exit 1) unless level A wins at least the share S (0-1)
## of the decided matches: the level gates of docs/ai-internals.md.

const DEFAULT_MATCHES: int = 100
const DEFAULT_SEED: int = 1
const USAGE: String = "Usage: -- [--matches N] [--seed S] [--start N] [--levels easy|normal|hard,easy|normal|hard] [--gate 0-1]"


func _initialize() -> void:
	var options: Dictionary = _parse(OS.get_cmdline_user_args())
	if options.is_empty():
		printerr(USAGE)
		quit(1)
		return
	var match_count: int = options.matches
	var seed_value: int = options.seed
	var levels: Array[int] = options.levels
	var first_match: int = options.start
	var stats: HarnessStats = Harness.run(RuleBook.load_default(), match_count, seed_value, levels, first_match)
	print("Ballen AI-vs-AI harness: %d matches from match %d, seed %d, %s vs %s" % [
		match_count, first_match, seed_value, AILevel.title(levels[0] as AILevel.Level), AILevel.title(levels[1] as AILevel.Level)])
	print("")
	print(stats.summary())
	var passed: bool = stats.finished() == stats.matches()
	if options.has("gate"):
		var share: float = stats.level_win_share(levels[0])
		var gate: float = options.gate
		var met: bool = levels[0] != levels[1] and share >= gate
		print("Gate: %s wins %.1f%% of decided matches, needs %.1f%%: %s" % [
			AILevel.title(levels[0] as AILevel.Level), share * 100.0, gate * 100.0, "met" if met else "NOT MET"])
		passed = passed and met
	quit(0 if passed else 1)


## {"matches": int, "seed": int, "start": int, "levels": Array[int]} and, with --gate,
## "gate": float; empty if an argument is unknown, lacks a value or is not
## valid.
func _parse(args: PackedStringArray) -> Dictionary:
	var levels: Array[int] = [AILevel.Level.NORMAL, AILevel.Level.NORMAL]
	var options: Dictionary = {"matches": DEFAULT_MATCHES, "seed": DEFAULT_SEED, "start": 0, "levels": levels}
	var i: int = 0
	while i < args.size():
		var key: String = args[i].trim_prefix("--")
		if i + 1 >= args.size():
			return {}
		var value: String = args[i + 1]
		match key:
			"matches", "seed", "start":
				if not value.is_valid_int():
					return {}
				options[key] = value.to_int()
			"levels":
				var parsed: Array[int] = _levels(value)
				if parsed.is_empty():
					return {}
				options.levels = parsed
			"gate":
				if not value.is_valid_float() or value.to_float() < 0.0 or value.to_float() > 1.0:
					return {}
				options.gate = value.to_float()
			_:
				return {}
		i += 2
	if options.matches < 1 or options.start < 0:
		return {}
	return options


## Two built levels from "a,b" by title, case aside; empty if not exactly two
## built levels.
func _levels(text: String) -> Array[int]:
	var levels: Array[int] = []
	for title: String in text.split(","):
		var found: bool = false
		for level: AILevel.Level in AILevel.ALL:
			if AILevel.title(level).to_lower() == title.strip_edges().to_lower() and AILevel.is_built(level):
				levels.append(level)
				found = true
		if not found:
			return []
	return levels if levels.size() == 2 else []
