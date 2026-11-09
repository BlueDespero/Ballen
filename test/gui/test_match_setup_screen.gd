extends GutTest

# The match setup screen teaches before it asks: the goal comes first, the
# picked rule's cells glow on a small board, Start names the pick, and the
# act-here cue moves from the rules to Start. Its card fits the screen with
# the longest rules at both text sizes.

const Fixtures := preload("res://test/helpers/fixtures.gd")
const SCREEN_SCENE: PackedScene = preload("res://gui/match_setup_screen.tscn")
const SCREEN_HEIGHT: float = 720.0
## The starter deck: R08 and R18 are its Simple rules.
const SIMPLE_IN_STARTER: Array[String] = ["R08", "R18"]
const LONGEST_RULES: Array[String] = ["R15", "R16", "R17", "R21", "R22"]

var _book: RuleBook
var _path: String
var _screen: MatchSetupScreen


func before_each() -> void:
	_book = Fixtures.book()
	_path = "user://test_match_setup_screen_%d.json" % OS.get_process_id()
	DirAccess.remove_absolute(_path)
	_screen = SCREEN_SCENE.instantiate()
	add_child_autofree(_screen)
	_screen.show_setup(DeckStore.new(_book, _path))


func after_each() -> void:
	DirAccess.remove_absolute(_path)


func _cue() -> Attention:
	for child: Node in _screen.get_children():
		if child is Attention:
			return child
	return null


func _rule_button(rule_id: String) -> Button:
	return _screen.get_node("%RuleButtons").get_node(rule_id)


func _tap(rule_id: String) -> void:
	_rule_button(rule_id).button_pressed = true
	_rule_button(rule_id).pressed.emit()


func test_it_opens_with_the_goal_and_the_stakes() -> void:
	assert_eq(_screen.get_node("%Title").text, "Name the AI's secret rule before it names yours.")
	assert_string_contains(_screen.find_child("Stakes").text, "Wrong guess loses")


func test_before_a_pick_nothing_glows_and_start_waits() -> void:
	assert_eq(_screen.get_node("%RulePreview").legal_cells, [] as Array[Vector2i])
	assert_true(_screen.get_node("%StartButton").disabled)
	assert_eq(_screen.get_node("%StartButton").text, "Start")


func test_a_pick_glows_its_cells_on_the_sample_board() -> void:
	_tap("R03")
	var preview: RulePreview = _screen.get_node("%RulePreview")
	var expected: Array[Vector2i] = RuleChecker.legal_cells(_book.rule("R03"), preview.sample, 0, preview.sample.colour)
	assert_false(expected.is_empty(), "the sample leaves R03 some cells")
	assert_lt(expected.size(), preview.sample.board.empty_cells().size(), "and forbids others")
	assert_eq(preview.legal_cells, expected)


func test_start_names_the_pick() -> void:
	_tap("R03")
	var start: Button = _screen.get_node("%StartButton")
	assert_false(start.disabled)
	assert_eq(start.text, "Start: R03 is my secret rule")


func test_the_cue_moves_from_the_rules_to_start() -> void:
	assert_eq(_cue().target, _screen.get_node("%RuleButtons"), "on the rules first")
	_tap("R05")
	assert_eq(_cue().target, _screen.get_node("%StartButton"), "on Start once a rule is picked")


func test_pick_for_me_picks_a_simple_rule() -> void:
	for seed_value: int in 10:
		_screen.rng = Fixtures.rng(seed_value)
		_screen.pick_for_me()
		var picked: String = _screen.get_node("%StartButton").text.trim_prefix("Start: ").trim_suffix(" is my secret rule")
		assert_has(SIMPLE_IN_STARTER, picked, "seed %d" % seed_value)
		assert_true(_rule_button(picked).button_pressed, "its button shows the pick")


func test_start_sends_the_picked_rule() -> void:
	watch_signals(_screen)
	_tap("R01")
	_screen.get_node("%StartButton").pressed.emit()
	var parameters: Array = get_signal_parameters(_screen, "start_requested")
	assert_eq(parameters[1], AILevel.Level.NORMAL)
	assert_eq((parameters[2] as Rule).id, "R01")


func test_the_card_fits_the_screen_with_the_longest_rules() -> void:
	var rules: Array[Rule] = []
	for rule_id: String in LONGEST_RULES:
		rules.append(_book.rule(rule_id))
	for scale: float in [1.0, Settings.LARGER_TEXT_SCALE]:
		_screen.text_scale = scale
		_screen.call("_show_deck", Deck.new(rules))
		_tap("R17")
		await wait_process_frames(3)
		var card: Control = _screen.get_node("%Card")
		assert_lte(card.get_combined_minimum_size().y, SCREEN_HEIGHT, "card height at text scale %s" % scale)


func test_start_reports_how_the_secret_rule_was_picked() -> void:
	watch_signals(EventBus)
	_screen.rng = Fixtures.rng(1)
	_screen.pick_for_me()
	_screen.get_node("%StartButton").pressed.emit()
	var parameters: Array = get_signal_parameters(EventBus, "secret_rule_picked")
	assert_has(SIMPLE_IN_STARTER, parameters[0])
	assert_gte(parameters[1] as float, 0.0, "seconds since the screen opened")
	assert_true(parameters[2], "Pick for me chose it")
	_tap("R03")
	_screen.get_node("%StartButton").pressed.emit()
	parameters = get_signal_parameters(EventBus, "secret_rule_picked")
	assert_eq(parameters[0], "R03")
	assert_false(parameters[2], "the player tapped it")
