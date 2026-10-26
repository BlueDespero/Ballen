extends Control

## The match scene: shows the match from the player's side and sends the
## player's commands. Before the match, the pre-match overlay lets the player
## choose a true rule from the starter deck while both decks are shown; then
## the coin toss is shown and play starts. The match decides what is legal; a
## MatchDriver runs the player's HumanController and the AI, pausing before
## each AI action.

const HUMAN: int = MatchSetup.PLAYER
const AI: int = MatchSetup.AI

const AI_FLY_SECONDS: float = 0.3
const MAIN_MENU_SCENE: String = "res://main.tscn"

@onready var _board_view: BoardView = %Board
@onready var _player_ball: BallView = %PlayerBall
@onready var _ai_ball: BallView = %AIBall
@onready var _picker: ColourPicker = %ColourPicker
@onready var _rules_panel: RulesPanel = %RulesPanel
@onready var _status: Label = %Status
@onready var _pre_match: PreMatchPanel = %PreMatch
@onready var _match_end: MatchEndOverlay = %MatchEnd

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _setup: MatchSetup
var _match: Match = null
var _human: HumanController = HumanController.new()
var _driver: MatchDriver = null
var _stalled_player: int = Players.NONE


func _ready() -> void:
	_rng.randomize()
	_player_ball.legality = _is_legal_for_player
	_player_ball.dropped.connect(_on_player_ball_dropped)
	_picker.picked.connect(_on_colour_picked)
	_rules_panel.guess_requested.connect(_on_guess_requested)
	_pre_match.rule_chosen.connect(_on_true_rule_chosen)
	_match_end.main_menu_requested.connect(_on_main_menu_requested)
	_show_pre_match()


func _exit_tree() -> void:
	if _driver != null:
		_driver.stop()
	_human.choose(null)


## Both decks on show and an empty board; the player chooses a true rule.
func _show_pre_match() -> void:
	_setup = MatchSetup.against_ai(RuleBook.load_default(), _rng)
	_rules_panel.show_decks(_setup.deck(AI), _setup.deck(HUMAN), null)
	_board_view.show_board(Board.new(), [], HUMAN, HUMAN)
	_player_ball.colour = ""
	_player_ball.draggable = false
	_ai_ball.colour = ""
	_picker.enabled = false
	_pre_match.show_deck(_setup.deck(HUMAN))
	_status.text = "Choose your true rule."


## Starts the match (its coin toss picks the first player), shows the toss,
## then lets the driver play.
func _on_true_rule_chosen(true_rule: Rule) -> void:
	_match = _setup.start(true_rule)
	var view: PublicView = _match.public_view(HUMAN)
	_rules_panel.show_decks(view.decks[AI], view.decks[HUMAN], view.own_true_rule)
	_board_view.show_board(view.position.board, [], HUMAN, view.position.first_player)
	var player_goes_first: bool = view.position.first_player == HUMAN
	_status.text = "You go first." if player_goes_first else "The AI goes first."
	await _pre_match.show_coin_toss(player_goes_first)
	var controllers: Array[Controller] = [_human, AIController.new(_rng)]
	_driver = MatchDriver.new(_match, controllers, [AI], _rng, _wait)
	_driver.changed.connect(_on_match_changed)
	_driver.stalled.connect(_on_match_stalled)
	_refresh()
	_driver.run()


## The driver awaits this before each AI action.
func _wait(seconds: float) -> Signal:
	return get_tree().create_timer(seconds).timeout


## The player's ball asks this, which asks the match.
func _is_legal_for_player(cell: Vector2i) -> bool:
	return _match != null and _match.current_player() == HUMAN and _match.is_legal(cell)


func _on_player_ball_dropped(cell: Vector2i) -> void:
	_human.choose(Command.place(cell))


func _on_colour_picked(colour: String) -> void:
	_human.choose(Command.pick_colour(colour))


func _on_guess_requested(rule_id: String) -> void:
	_human.choose(Command.guess(rule_id))


func _on_main_menu_requested() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


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
	_rules_panel.guess_enabled = my_turn and view.can_guess()
	_status.text = _status_text(view)
	if view.phase == Match.Phase.OVER:
		_rules_panel.show_match_over(view.revealed_true_rules[AI])
		_match_end.show_summary(MatchEndSummary.from_view(view))


## What to do now; empty once the match is over (the match-end screen says how
## it went).
func _status_text(view: PublicView) -> String:
	if _stalled_player != Players.NONE:
		var who: String = "You have" if _stalled_player == HUMAN else "The AI has"
		return "%s no legal cell. Skips are not built yet, so the match stops here." % who
	if view.phase == Match.Phase.OVER:
		return ""
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
