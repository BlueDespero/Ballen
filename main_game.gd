extends Control

## The match scene: shows the match from the player's side and sends the
## player's commands. Before the match, the match setup screen lets the player
## pick a deck and the AI level and choose a true rule while both decks are
## shown; then the coin toss is shown and play starts. The match decides what is
## legal; a MatchDriver runs the player's HumanController and the AI, pausing
## before each AI action. At match end, Rematch goes back to the setup screen
## to choose a true rule on the same decks at the same level.
##
## The history view (the arrows and Live under the board, or the ← and → keys)
## steps turn by turn through past boards, rebuilt from the player's view; a
## HistoryBrowser keeps which turn is on show. It only shows: the glow and
## dragging pause, and only the player's own actions (pressing their ball, a
## colour pick, Guess or Seal, Live, or stepping past the latest turn) return
## to the live board. The AI playing on meanwhile leaves the past board on show
## and lights up Live.

const HUMAN: int = MatchSetup.PLAYER
const AI: int = MatchSetup.AI

const AI_FLY_SECONDS: float = 0.3
## A skipped ball stays at its owner's side this long, labelled, then
## dissolves; the driver holds the match until it is gone.
const SKIP_HOLD_SECONDS: float = 1.5
const SKIP_DISSOLVE_SECONDS: float = 0.8
const MAIN_MENU_SCENE: String = "res://main.tscn"
## On the status line whenever the player's colour pick is due.
const PICK_PROMPT: String = "Pick the AI's next colour."
## The waiting balls fade to this while a past board is on show.
const PAUSED_BALL_ALPHA: float = 0.35

@onready var _board_view: BoardView = %Board
@onready var _player_ball: BallView = %PlayerBall
@onready var _ai_ball: BallView = %AIBall
@onready var _player_skip_note: Label = %PlayerSkipNote
@onready var _ai_skip_note: Label = %AISkipNote
@onready var _picker: ColourPicker = %ColourPicker
@onready var _rules_panel: RulesPanel = %RulesPanel
@onready var _status: Label = %Status
@onready var _setup_screen: MatchSetupScreen = %MatchSetup
@onready var _match_end: MatchEndOverlay = %MatchEnd
@onready var _history_nav: HistoryNav = %HistoryNav

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _book: RuleBook = RuleBook.load_default()
## Null until the first Start; then kept for rematches.
var _setup: MatchSetup = null
## Drawn when the setup screen opens, so the player sees it before Start.
var _ai_deck: Deck = null
var _match: Match = null
var _human: HumanController = HumanController.new()
var _driver: MatchDriver = null
## How many history events the screen has shown.
var _shown_events: int = 0
## The history view's state; it holds the player's view as last drawn, and is
## busy while a run of _on_match_changed shows new events.
var _history: HistoryBrowser = HistoryBrowser.new()


func _ready() -> void:
	_rng.randomize()
	_player_ball.legality = _is_legal_for_player
	_player_ball.dropped.connect(_on_player_ball_dropped)
	_picker.picked.connect(_on_colour_picked)
	_rules_panel.guess_requested.connect(_on_guess_requested)
	_rules_panel.seal_requested.connect(_on_seal_requested)
	_setup_screen.deck_shown.connect(_on_setup_deck_shown)
	_setup_screen.start_requested.connect(_on_start_requested)
	_setup_screen.main_menu_requested.connect(_on_main_menu_requested)
	_match_end.rematch_requested.connect(_on_rematch_requested)
	_match_end.main_menu_requested.connect(_on_main_menu_requested)
	_history_nav.back_pressed.connect(_step_back)
	_history_nav.live_pressed.connect(_go_live)
	_history_nav.forward_pressed.connect(_step_forward)
	Settings.changed.connect(_apply_settings)
	_apply_settings()
	_show_setup()


func _exit_tree() -> void:
	if _driver != null:
		_driver.stop()
	_human.choose(null)


## Passes the player's settings (the Settings autoload) on to the views.
func _apply_settings() -> void:
	_board_view.symbols = Settings.colour_blind_symbols
	_player_ball.symbols = Settings.colour_blind_symbols
	_ai_ball.symbols = Settings.colour_blind_symbols
	_picker.symbols = Settings.colour_blind_symbols
	_history_nav.reduced_motion = Settings.reduced_motion
	_board_view.reduced_motion = Settings.reduced_motion
	_player_ball.reduced_motion = Settings.reduced_motion
	_ai_ball.reduced_motion = Settings.reduced_motion
	_picker.reduced_motion = Settings.reduced_motion
	_rules_panel.guess_without_holding = Settings.guess_without_holding
	_rules_panel.text_scale = Settings.text_scale()
	_setup_screen.text_scale = Settings.text_scale()
	TextScale.apply(_match_end, Settings.text_scale())


## An empty board under the match setup screen: a new match draws the AI's
## deck and offers the saved decks and the AI levels; a rematch keeps the decks
## and level (the setup keeps them) and the player chooses a true rule again.
## The rules panel shows the AI's deck beside the screen.
func _show_setup() -> void:
	_rules_panel.show_skips(0, 0)
	_board_view.show_board(Board.new(), [], HUMAN, HUMAN)
	_player_ball.colour = ""
	_player_ball.draggable = false
	_ai_ball.colour = ""
	_picker.enabled = false
	if _setup == null:
		_ai_deck = Deck.draw(_book, _rng)
		_setup_screen.show_setup(DeckStore.new(_book))
	else:
		_setup_screen.show_rematch()
	_status.text = ""
	_history.reset()
	_update_history_nav()


## Both decks in the rules panel while the player chooses a true rule.
func _on_setup_deck_shown(deck: Deck) -> void:
	_rules_panel.show_decks(_ai_deck, deck, null)


## Starts the match (its coin toss picks the first player; in a rematch the
## other player goes first), shows who goes first, then lets the driver play.
func _on_start_requested(deck: Deck, level: AILevel.Level, true_rule: Rule) -> void:
	var is_rematch: bool = _match != null
	if not is_rematch:
		_setup = MatchSetup.against_ai(deck, _ai_deck, level, _rng)
	_match = _setup.rematch(true_rule) if is_rematch else _setup.start(true_rule)
	_shown_events = 0
	var view: PublicView = _match.public_view(HUMAN)
	_rules_panel.show_decks(view.decks[AI], view.decks[HUMAN], view.own_true_rule)
	_board_view.show_board(view.position.board, [], HUMAN, view.position.first_player)
	var player_goes_first: bool = view.position.first_player == HUMAN
	_status.text = "You go first." if player_goes_first else "The AI goes first."
	await _setup_screen.show_coin_toss(player_goes_first, is_rematch)
	var controllers: Array[Controller] = [_human, AIController.new(_rng)]
	_driver = MatchDriver.new(_match, controllers, [AI], _rng, _wait, SKIP_HOLD_SECONDS + SKIP_DISSOLVE_SECONDS)
	_driver.changed.connect(_on_match_changed)
	_redraw_from_match()
	EventBus.match_started.emit(player_goes_first)
	_driver.run()


## The driver awaits this before each AI action and while a skip is shown.
func _wait(seconds: float) -> Signal:
	return get_tree().create_timer(seconds).timeout


## The player's ball asks this, which asks the match.
func _is_legal_for_player(cell: Vector2i) -> bool:
	return _match != null and _match.current_player() == HUMAN and _match.is_legal(cell)


func _on_player_ball_dropped(cell: Vector2i) -> void:
	_human.choose(Command.place(cell))


## The player's own actions return to the live board first, so what they
## cause animates there.
func _on_colour_picked(colour: String) -> void:
	_go_live()
	_human.choose(Command.pick_colour(colour))


## Guess names the AI's true rule outright: right wins, wrong loses.
func _on_guess_requested(rule_id: String) -> void:
	_go_live()
	_human.choose(Command.guess(rule_id))


## On a full board, Seal makes the player's sealed forced guess.
func _on_seal_requested(rule_id: String) -> void:
	_go_live()
	_human.choose(Command.forced_guess(rule_id))


## Back to the setup screen to choose a true rule for the next match on the
## same decks.
func _on_rematch_requested() -> void:
	_match_end.hide_summary()
	_show_setup()


func _on_main_menu_requested() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


## One command can add several events (a colour pick, then the next player's
## skip), so every event since the last redraw is shown in order. One run shows
## them all: a change that comes in while it animates is picked up by its loop,
## so the history view never opens mid-animation. While a past board is on
## show nothing animates: it stays on show and Live lights up, until the match
## is over.
func _on_match_changed() -> void:
	if _history.busy:
		return
	_history.busy = true
	_update_history_nav()
	while _shown_events < _match.history().size():
		var event: HistoryEntry = _match.history()[_shown_events]
		_shown_events += 1
		var animates: bool = not _history.viewing_past()
		if animates and event.type == HistoryEntry.Type.PLACEMENT and event.player == AI:
			await _ai_ball.fly_to(_board_view.cell_centre(event.cell), AI_FLY_SECONDS)
		elif animates and event.type == HistoryEntry.Type.SKIP:
			await _show_skip(event)
		if event.type == HistoryEntry.Type.PLACEMENT:
			EventBus.ball_placed.emit(event.player == HUMAN, event.cell)
	_history.busy = false
	_redraw_from_match()


## The skipped ball appears at its owner's side with a note, stays, then
## dissolves with it. No input meanwhile; the skip pip fills on the redraw
## after.
func _show_skip(skip: HistoryEntry) -> void:
	_player_ball.draggable = false
	_picker.enabled = false
	_rules_panel.guess_enabled = false
	_rules_panel.seal_enabled = false
	_status.text = ""
	var ball: BallView = _waiting_ball(skip.player)
	var note: Label = _player_skip_note if skip.player == HUMAN else _ai_skip_note
	note.modulate.a = 1.0
	note.visible = true
	# The player's note sits where the history arrows are.
	_history_nav.visible = skip.player != HUMAN
	# With reduced motion the note goes with the ball, without fading.
	var fade_seconds: float = 0.0 if Settings.reduced_motion else SKIP_DISSOLVE_SECONDS
	var fade: Tween = note.create_tween()
	fade.tween_interval(SKIP_HOLD_SECONDS + SKIP_DISSOLVE_SECONDS - fade_seconds)
	fade.tween_property(note, "modulate:a", 0.0, fade_seconds)
	await ball.dissolve(skip.colour, SKIP_HOLD_SECONDS, SKIP_DISSOLVE_SECONDS)
	note.visible = false
	_history_nav.visible = true


## The player's waiting ball under the board, or the AI's above it.
func _waiting_ball(player: int) -> BallView:
	return _player_ball if player == HUMAN else _ai_ball


## Pressing your ball while a past board is on show is an action: back to the
## live board (the press then starts the drag). The arrow keys step through
## history.
func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed:
		if key.keycode == KEY_LEFT:
			_step_back()
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_RIGHT:
			_step_forward()
			get_viewport().set_input_as_handled()
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if (button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT
			and _history.viewing_past() and _player_ball.get_global_rect().has_point(button.global_position)):
		_go_live()


func _step_back() -> void:
	if _history.step_back():
		_show_viewed_board()


func _step_forward() -> void:
	if _history.step_forward():
		_show_viewed_board()


func _go_live() -> void:
	if _history.go_live():
		_show_viewed_board()


func _update_history_nav() -> void:
	_history_nav.set_state(_history.can_go_back(), _history.viewing_past(), _history.moved_on)


## Takes the player's view of the match afresh and redraws everything from it.
func _redraw_from_match() -> void:
	_history.live_view = _match.public_view(HUMAN)
	_show_viewed_board()


## Shows the live board, or the past turn the history view is on. Either way
## the player's actions (colour pick, Guess, Seal) follow the live match.
func _show_viewed_board() -> void:
	_show_actions(_history.live_view)
	if _history.viewing_past():
		_show_past_turn()
	else:
		_show_live_match(_history.live_view)
	_update_history_nav()


## Which of the player's actions are open now.
func _show_actions(view: PublicView) -> void:
	_picker.enabled = view.colour_pick_due()
	_rules_panel.board_full = view.phase == Match.Phase.FORCED_GUESS
	_rules_panel.guess_enabled = view.current_player == HUMAN and view.can_guess()
	_rules_panel.seal_enabled = view.forced_guess_due()


## The past turn on show: the board right after it with its ball ringed, or
## its skipped ball on its owner's waiting spot; the waiting balls fade and
## nothing glows or drags.
func _show_past_turn() -> void:
	var past: MatchPosition = _history.past_position()
	var event: HistoryEntry = past.history[-1]
	var placed: bool = event.type == HistoryEntry.Type.PLACEMENT
	_board_view.show_board(past.board, [], HUMAN, past.first_player, event.cell if placed else BoardView.NO_CELL)
	_player_ball.reset()
	_player_ball.draggable = false
	_player_ball.modulate.a = PAUSED_BALL_ALPHA
	_ai_ball.reset()
	_ai_ball.modulate.a = PAUSED_BALL_ALPHA
	if not placed:
		var owner_ball: BallView = _waiting_ball(event.player)
		owner_ball.colour = event.colour
		owner_ball.modulate.a = 1.0
	_rules_panel.show_skips(past.skips[AI], past.skips[HUMAN])
	_status.text = _history.past_turn_text()


## The live board and everything around it, from the player's view.
func _show_live_match(view: PublicView) -> void:
	var my_turn: bool = view.current_player == HUMAN
	var my_placement: bool = my_turn and view.phase == Match.Phase.PLACE
	var ai_placement: bool = view.current_player == AI and view.phase == Match.Phase.PLACE
	_board_view.show_board(view.position.board, view.own_legal_cells(), HUMAN, view.position.first_player)
	_player_ball.reset()
	_player_ball.colour = view.position.colour if view.current_player == HUMAN and view.phase == Match.Phase.PLACE else ""
	_player_ball.draggable = my_placement
	_ai_ball.reset()
	_ai_ball.colour = view.position.colour if ai_placement else ""
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
			return tr("You had no legal cell for %s, so your ball was skipped. %s") % [BallColour.word(skip.colour), tr(PICK_PROMPT)]
		return tr("The AI had no legal cell for %s, so its ball was skipped. The AI is thinking…") % BallColour.word(skip.colour)
	if view.current_player == AI:
		if view.phase == Match.Phase.FIRST_COLOUR:
			return "You go first. The AI is picking your first colour…"
		return "The AI is thinking…"
	match view.phase:
		Match.Phase.FIRST_COLOUR:
			return tr("The AI goes first.") + " " + tr(PICK_PROMPT)
		Match.Phase.PLACE:
			return "Your turn. Drag your ball onto a glowing cell."
		Match.Phase.PICK_COLOUR:
			return tr(PICK_PROMPT) + " " + tr("That ends your turn.")
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
