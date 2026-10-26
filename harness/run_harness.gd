extends SceneTree

## Command-line entry point of the AI-vs-AI harness. From the repo root:
##     godot --headless --path . -s harness/run_harness.gd -- --matches 100 --seed 1
## Plays the matches with no pauses and prints the summary. Exit code 0 when
## every match finished, 1 otherwise (or on a bad argument).

const DEFAULT_MATCHES: int = 100
const DEFAULT_SEED: int = 1


func _initialize() -> void:
	var options: Dictionary = _parse(OS.get_cmdline_user_args())
	if options.is_empty():
		printerr("Usage: -- [--matches N] [--seed S]")
		quit(1)
		return
	var match_count: int = options.matches
	var seed_value: int = options.seed
	var stats: HarnessStats = Harness.run(RuleBook.load_default(), match_count, seed_value)
	print("Ballen AI-vs-AI harness: %d matches, seed %d" % [match_count, seed_value])
	print("")
	print(stats.summary())
	quit(0 if stats.finished() == stats.matches() else 1)


## {"matches": int, "seed": int} from --matches and --seed; empty if an
## argument is unknown, lacks a value or isn't a whole number.
func _parse(args: PackedStringArray) -> Dictionary:
	var options: Dictionary = {"matches": DEFAULT_MATCHES, "seed": DEFAULT_SEED}
	var i: int = 0
	while i < args.size():
		var key: String = args[i].trim_prefix("--")
		if not options.has(key) or i + 1 >= args.size() or not args[i + 1].is_valid_int():
			return {}
		options[key] = args[i + 1].to_int()
		i += 2
	if options.matches < 1:
		return {}
	return options
