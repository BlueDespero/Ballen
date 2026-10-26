extends Control

## The match scene: shows the match from the player's side and sends the
## player's commands. The match decides what is legal; a MatchDriver runs the
## player's HumanController and the AI, pausing before each AI action.

const HUMAN: int = 0
const AI: int = 1

## Until the pre-match pick exists, both players get this true rule. Each deck
## is the true rule plus 4 other built rules, the player's preferring the
## starter deck.
const FIXED_TRUE_RULE_ID: String = "R04"
const STARTER_DECK_IDS: Array[String] = ["R01", "R03", "R05", "R08", "R18"]

const AI_FLY_SECONDS: float = 0.3

@onready var _board_view: BoardView = %Board
@onready var _player_ball: BallView = %PlayerBall
@onready var _ai_ball: BallView = %AIBall
@onready var _picker: ColourPicker = %ColourPicker
@onready var _rules_panel: RulesPanel = %RulesPanel
@onready var _status: Label = %Status

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _match: Match
var _human: HumanController = HumanController.new()
var _driver: MatchDriver
var _stalled_player: int = Players.NONE


func _ready() -> void:
	_rng.randomize()
	_match = _new_match()
	var view: PublicView = _match.public_view(HUMAN)
	_rules_panel.show_decks(view.decks[AI], view.decks[HUMAN], view.own_true_rule)
	_player_ball.legality = _is_legal_for_player
	_player_ball.dropped.connect(_on_player_ball_dropped)
	_picker.picked.connect(_on_colour_picked)
	var controllers: Array[Controller] = [_human, AIController.new(_rng)]
	_driver = MatchDriver.new(_match, controllers, [AI], _rng, _wait)
	_driver.changed.connect(_on_match_changed)
	_driver.stalled.connect(_on_match_stalled)
	_refresh()
	_driver.run()


func _exit_tree() -> void:
	_driver.stop()
	_human.choose(null)


func _new_match() -> Match:
	var book: RuleBook = RuleBook.load_default()
	var true_rule: Rule = book.rule(FIXED_TRUE_RULE_ID)
	var decks: Array[Deck] = []
	decks.resize(Players.COUNT)
	decks[HUMAN] = _deck(book, true_rule, STARTER_DECK_IDS)
	decks[AI] = _deck(book, true_rule, book.rule_ids())
	var true_rules: Array[Rule] = [true_rule, true_rule]
	return Match.create(decks, true_rules, _rng)


func _deck(book: RuleBook, true_rule: Rule, preferred_ids: Array[String]) -> Deck:
	var rules: Array[Rule] = [true_rule]
	for rule_id: String in preferred_ids + book.rule_ids():
		var rule: Rule = book.rule(rule_id)
		if rule != null and not rules.has(rule) and rules.size() < Deck.SIZE:
			rules.append(rule)
	return Deck.new(rules)


## The driver awaits this before each AI action.
func _wait(seconds: float) -> Signal:
	return get_tree().create_timer(seconds).timeout


## The player's ball asks this, which asks the match.
func _is_legal_for_player(cell: Vector2i) -> bool:
	return _match.current_player() == HUMAN and _match.is_legal(cell)


func _on_player_ball_dropped(cell: Vector2i) -> void:
	_human.choose(Command.place(cell))


func _on_colour_picked(colour: String) -> void:
	_human.choose(Command.pick_colour(colour))


func _on_match_changed() -> void:
	var history: Array[HistoryEntry] = _match.history()
	var last: HistoryEntry = history[-1]
	if last.type == HistoryEntry.Type.PLACEMENT and last.player == AI:
		await _ai_ball.fly_to(_board_view.cell_centre(last.cell), AI_FLY_SECONDS)
	_refresh()


func _on_match_stalled(player: int) -> void:
	_stalled_player = player
	_refresh()


## Redraws everything from the player's view of the match.
func _refresh() -> void:
	var view: PublicView = _match.public_view(HUMAN)
	var my_turn: bool = view.current_player == HUMAN and _stalled_player == Players.NONE
	var my_placement: bool = my_turn and view.phase == Match.Phase.PLACE
	var ai_placement: bool = view.current_player == AI and view.phase == Match.Phase.PLACE
	var legal: Array[Vector2i] = []
	if my_placement:
		legal = _match.legal_cells()
	_board_view.show_board(view.position.board, legal, HUMAN, view.position.first_player)
	_player_ball.reset()
	_player_ball.colour = view.position.colour if view.current_player == HUMAN and view.phase == Match.Phase.PLACE else ""
	_player_ball.draggable = my_placement
	_ai_ball.reset()
	_ai_ball.colour = view.position.colour if ai_placement else ""
	_picker.enabled = my_turn and (view.phase == Match.Phase.FIRST_COLOUR or view.phase == Match.Phase.PICK_COLOUR)
	_status.text = _status_text(view)


func _status_text(view: PublicView) -> String:
	if _stalled_player != Players.NONE:
		var who: String = "You have" if _stalled_player == HUMAN else "The AI has"
		return "%s no legal cell. Skips are not built yet, so the match stops here." % who
	if view.phase == Match.Phase.OVER:
		return "The match is over."
	if view.current_player == AI:
		if view.phase == Match.Phase.FIRST_COLOUR:
			return "You go first. The AI is picking your first colour…"
		return "The AI is thinking…"
	match view.phase:
		Match.Phase.FIRST_COLOUR:
			return "The AI goes first. Pick the colour of its first ball."
		Match.Phase.PLACE:
			return "Your turn. Drag your ball onto a glowing cell."
		Match.Phase.PICK_COLOUR:
			return "Pick the colour of the AI's next ball. That ends your turn."
	return ""
