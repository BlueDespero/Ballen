extends SceneTree

## Command-line entry point of the strictness check. From the repo root:
##     godot --headless --path . -s harness/run_strictness.gd -- --boards 2000 --seed 1
## Measures every rule of the rule book on the same seeded random positions
## and prints one row per rule. Exit code 0, or 1 on a bad argument.

const DEFAULT_BOARDS: int = 2000
const DEFAULT_SEED: int = 1


func _initialize() -> void:
	var options: Dictionary = _parse(OS.get_cmdline_user_args())
	if options.is_empty():
		printerr("Usage: -- [--boards N] [--seed S]")
		quit(1)
		return
	var board_count: int = options.boards
	var seed_value: int = options.seed
	var book: RuleBook = RuleBook.load_default()
	var rules: Array[Rule] = []
	for rule_id: String in book.rule_ids():
		rules.append(book.rule(rule_id))
	var positions: Array[MatchPosition] = StrictnessCheck.random_positions(board_count, seed_value)
	print("Ballen strictness check: %d random boards, seed %d" % [board_count, seed_value])
	print("")
	print(StrictnessCheck.summary(rules, positions))
	quit(0)


## {"boards": int, "seed": int} from --boards and --seed; empty if an
## argument is unknown, lacks a value or isn't a whole number.
func _parse(args: PackedStringArray) -> Dictionary:
	var options: Dictionary = {"boards": DEFAULT_BOARDS, "seed": DEFAULT_SEED}
	var i: int = 0
	while i < args.size():
		var key: String = args[i].trim_prefix("--")
		if not options.has(key) or i + 1 >= args.size() or not args[i + 1].is_valid_int():
			return {}
		options[key] = args[i + 1].to_int()
		i += 2
	if options.boards < 1:
		return {}
	return options
