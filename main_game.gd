extends Control

## The match scene: shows the match from the player's side and sends the
## player's commands. Before the match, the pre-match overlay lets the player
## choose a true rule from the starter deck while both decks are shown; then
## the coin toss is shown and play starts. The match decides what is legal; a
## MatchDriver runs the player's HumanController and the AI, pausing before
## each AI action. At match end, Rematch goes back to choosing a true rule
## on the same decks.

const HUMAN: int = MatchSetup.PLAYER
const AI: int = MatchSetup.AI

const AI_FLY_SECONDS: float = 0.3
## Shorter than the AI's shortest pause, so a skip is shown before its next action.
const SKIP_DISSOLVE_SECONDS: float = 0.4
const MAIN_MENU_SCENE: String = "res://main.tscn"
## On the status line whenever the player's colour pick is due.
const PICK_PROMPT: String = "Pick the AI's next colour."

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
## How many history events the screen has shown.
var _shown_events: int = 0


func _ready() -> void:
	_rng.randomize()
	_player_ball.legality = _is_legal_for_player
	_player_ball.dropped.connect(_on_player_ball_dropped)
	_picker.picked.connect(_on_colour_picked)
	_rules_panel.guess_requested.connect(_on_guess_requested)
	_rules_panel.seal_requested.connect(_on_seal_requested)
	_pre_match.rule_chosen.connect(_on_true_rule_chosen)
	_match_end.rematch_requested.connect(_on_rematch_requested)
	_match_end.main_menu_requested.connect(_on_main_menu_requested)
	_setup = MatchSetup.against_ai(RuleBook.load_default(), _rng)
	_show_pre_match()


func _exit_tree() -> void:
	if _driver != null:
		_driver.stop()
	_human.choose(null)


## Both decks on show and an empty board; the player chooses a true rule
## (again, in a rematch: the setup keeps both decks).
func _show_pre_match() -> void:
	_rules_panel.show_decks(_setup.deck(AI), _setup.deck(HUMAN), null)
	_rules_panel.show_skips(0, 0)
	_board_view.show_board(Board.new(), [], HUMAN, HUMAN)
	_player_ball.colour = ""
	_player_ball.draggable = false
	_ai_ball.colour = ""
	_picker.enabled = false
	_pre_match.show_deck(_setup.deck(HUMAN))
	_status.text = "Choose your true rule."


## Starts the match (its coin toss picks the first player; in a rematch the
## other player goes first), shows who goes first, then lets the driver play.
func _on_true_rule_chosen(true_rule: Rule) -> void:
	var is_rematch: bool = _match != null
	_match = _setup.rematch(true_rule) if is_rematch else _setup.start(true_rule)
	_shown_events = 0
	var view: PublicView = _match.public_view(HUMAN)
	_rules_panel.show_decks(view.decks[AI], view.decks[HUMAN], view.own_true_rule)
	_board_view.show_board(view.position.board, [], HUMAN, view.position.first_player)
	var player_goes_first: bool = view.position.first_player == HUMAN
	_status.text = "You go first." if player_goes_first else "The AI goes first."
	await _pre_match.show_coin_toss(player_goes_first, is_rematch)
	var controllers: Array[Controller] = [_human, AIController.new(_rng)]
	_driver = MatchDriver.new(_match, controllers, [AI], _rng, _wait)
	_driver.changed.connect(_on_match_changed)
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


## Guess names the AI's true rule outright: right wins, wrong loses.
func _on_guess_requested(rule_id: String) -> void:
	_human.choose(Command.guess(rule_id))


## On a full board, Seal makes the player's sealed forced guess.
func _on_seal_requested(rule_id: String) -> void:
	_human.choose(Command.forced_guess(rule_id))


## Back to choosing a true rule for the next match on the same decks.
func _on_rematch_requested() -> void:
	_match_end.hide_summary()
	_show_pre_match()


func _on_main_menu_requested() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


## One command can add several events (a colour pick, then the next player's
## skip), so every event since the last redraw is shown in order.
func _on_match_changed() -> void:
	var history: Array[HistoryEntry] = _match.history()
	var first_new: int = _shown_events
	_shown_events = history.size()
	for i: int in range(first_new, history.size()):
		var event: HistoryEntry = history[i]
		if event.type == HistoryEntry.Type.PLACEMENT and event.player == AI:
			await _ai_ball.fly_to(_board_view.cell_centre(event.cell), AI_FLY_SECONDS)
		elif event.type == HistoryEntry.Type.SKIP:
			var ball: BallView = _player_ball if event.player == HUMAN else _ai_ball
			await ball.dissolve(event.colour, SKIP_DISSOLVE_SECONDS)
	_refresh()


## Redraws everything from the player's view of the match.
func _refresh() -> void:
	var view: PublicView = _match.public_view(HUMAN)
	var my_turn: bool = view.current_player == HUMAN
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
	_picker.enabled = view.colour_pick_due()
	_rules_panel.board_full = view.phase == Match.Phase.FORCED_GUESS
	_rules_panel.guess_enabled = my_turn and view.can_guess()
	_rules_panel.seal_enabled = view.forced_guess_due()
	_rules_panel.show_skips(view.position.skips[AI], view.position.skips[HUMAN])
	_status.text = _status_text(view)
	if view.phase == Match.Phase.OVER:
		_rules_panel.show_match_over(view.revealed_true_rules[AI])
		_match_end.show_summary(MatchEndSummary.from_view(view))


## What to do now; empty once the match is over (the match-end screen says how
## it went).
func _status_text(view: PublicView) -> String:
	if view.phase == Match.Phase.OVER:
		return ""
	if view.phase == Match.Phase.FORCED_GUESS:
		return _forced_guess_text(view)
	var skip: HistoryEntry = _skip_this_turn(view)
	if skip != null:
		if skip.player == HUMAN:
			return "You had no legal cell for %s, so your ball was skipped. %s" % [skip.colour, PICK_PROMPT]
		return "The AI had no legal cell for %s, so its ball was skipped. The AI is thinking…" % skip.colour
	if view.current_player == AI:
		if view.phase == Match.Phase.FIRST_COLOUR:
			return "You go first. The AI is picking your first colour…"
		return "The AI is thinking…"
	match view.phase:
		Match.Phase.FIRST_COLOUR:
			return "The AI goes first. " + PICK_PROMPT
		Match.Phase.PLACE:
			return "Your turn. Drag your ball onto a glowing cell."
		Match.Phase.PICK_COLOUR:
			return PICK_PROMPT + " That ends your turn."
	return ""


## The current player's skip, if their turn started with one; null otherwise.
func _skip_this_turn(view: PublicView) -> HistoryEntry:
	var history: Array[HistoryEntry] = view.position.history
	if view.phase != Match.Phase.PICK_COLOUR or history.is_empty():
		return null
	var last: HistoryEntry = history[-1]
	if last.type == HistoryEntry.Type.SKIP and last.player == view.current_player:
		return last
	return null


## The board is full: whose forced guess is due. A sealed guess is never shown.
func _forced_guess_text(view: PublicView) -> String:
	if view.forced_guess_due() and view.can_guess():
		return "The board is full. Guess the AI's true rule now, or seal your forced guess until both are in."
	if view.forced_guess_due():
		return "The board is full. Name the AI's true rule: it stays sealed until both guesses are in."
	if view.current_player == HUMAN:
		return "The board is full and your forced guess is sealed. The AI is guessing…"
	return "The board is full. The AI is making its forced guess…"
