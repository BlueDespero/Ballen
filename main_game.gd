extends Control

## The match scene: shows the match from the player's side and sends the
## player's commands. Before the match, the match setup screen lets the player
## pick a deck and the AI level and choose a secret rule while both decks are
## shown; then the coin toss is shown and play starts. The match decides what is
## legal; a MatchDriver runs the player's HumanController and the AI, pausing
## before each AI action. At match end, Rematch goes back to the setup screen
## to choose a secret rule on the same decks at the same level.
##
## The history view (the arrows and Live under the board, or the ← and → keys)
## steps turn by turn through past boards, rebuilt from the player's view; a
## HistoryBrowser keeps which turn is on show. It only shows: the glow and
## dragging pause, and only the player's own actions (pressing their ball, a
## colour pick, Guess or Seal, Live, or stepping past the latest turn) return
## to the live board. The AI playing on meanwhile leaves the past board on show
## and lights up Live.
##
## Back (Escape, or Android's back button) during a match, from the coin toss
## to the last move, asks "Leave this match?"; leaving goes to the main menu
## and records nothing. The setup and match-end screens take back themselves.

const HUMAN: int = MatchSetup.PLAYER
const AI: int = MatchSetup.AI

const AI_FLY_SECONDS: float = 0.3
## A skipped ball stays at its owner's side this long, labelled, then
## dissolves; the driver holds the match until it is gone.
const SKIP_HOLD_SECONDS: float = 1.5
const SKIP_DISSOLVE_SECONDS: float = 0.8
const MAIN_MENU_SCENE: String = "res://main.tscn"
## The waiting balls fade to this while a past board is on show.
const PAUSED_BALL_ALPHA: float = 0.35
## Where each one-time hint's bottom-right corner sits in the layout: over the
## board's bottom right, just above the colour picker (the board takes no input
## while the pick is due), and above the board's top right, beside the AI's
## rules.
const HINT_CORNERS: Dictionary[String, Vector2] = {
	GameSettings.HINT_COLOUR_PICK: Vector2(704, 628),
	GameSettings.HINT_WATCH_AI: Vector2(736, 112),
}
## The layout's built size; it shrinks to fit a smaller screen (one inset
## for a camera cutout), centred.
const LAYOUT_SIZE: Vector2 = Vector2(1280, 720)

@onready var _layout: Control = $Layout
@onready var _board_view: BoardView = %Board
@onready var _player_ball: BallView = %PlayerBall
@onready var _ai_ball: BallView = %AIBall
@onready var _player_skip_note: Label = %PlayerSkipNote
@onready var _ai_skip_note: Label = %AISkipNote
@onready var _picker: ColourPicker = %ColourPicker
@onready var _rules_panel: RulesPanel = %RulesPanel
## The prompt beside the board, and its detail line under it (TurnPrompt).
@onready var _status: Label = %Status
@onready var _status_detail: Label = %StatusDetail
@onready var _setup_screen: MatchSetupScreen = %MatchSetup
@onready var _match_end: MatchEndOverlay = %MatchEnd
@onready var _history_nav: HistoryNav = %HistoryNav
@onready var _leave_dialog: LeaveMatchDialog = %LeaveMatch

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
## The act-here cue: on the player's ball while they place, on the colour
## picker while their pick is due, nowhere otherwise.
var _cue: Attention = Attention.new()
## A one-time hint for a new player (CoachMark.hint_for), beside what it explains.
var _coach: CoachMark = CoachMark.new()


func _ready() -> void:
	_rng.randomize()
	_player_ball.legality = _is_legal_for_player
	_player_ball.dropped.connect(_on_player_ball_dropped)
	_board_view.cell_pressed.connect(_on_cell_pressed)
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
	add_child(_cue)
	$Layout.add_child(_coach)
	# Above the cue, which is added after the scene's own nodes.
	move_child(_leave_dialog, -1)
	_leave_dialog.leave_confirmed.connect(_on_main_menu_requested)
	Settings.changed.connect(_apply_settings)
	_apply_settings()
	resized.connect(_fit_layout)
	_fit_layout()
	_show_setup()


func _exit_tree() -> void:
	if _driver != null:
		_driver.stop()
	_human.choose(null)


## How much the layout shrinks to fit a screen of this size: never grows.
static func layout_scale(screen_size: Vector2) -> float:
	return minf(1.0, minf(screen_size.x / LAYOUT_SIZE.x, screen_size.y / LAYOUT_SIZE.y))


func _fit_layout() -> void:
	_layout.pivot_offset = LAYOUT_SIZE / 2.0
	_layout.scale = Vector2.ONE * layout_scale(size)


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
	_cue.reduced_motion = Settings.reduced_motion
	_rules_panel.hold_to_guess = Settings.hold_to_guess
	_rules_panel.text_scale = Settings.text_scale()
	_setup_screen.text_scale = Settings.text_scale()
	TextScale.apply(_match_end, Settings.text_scale())
	TextScale.apply(_coach, Settings.text_scale())
	TextScale.apply(_leave_dialog, Settings.text_scale())


## An empty board under the match setup screen: a new match draws the AI's
## deck and offers the saved decks and the AI levels; a rematch keeps the decks
## and level (the setup keeps them) and the player chooses a secret rule again.
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
	_show_status(TurnPrompt.new())
	_history.reset()
	_update_history_nav()


## Both decks in the rules panel while the player chooses a secret rule.
func _on_setup_deck_shown(deck: Deck) -> void:
	_rules_panel.show_decks(_ai_deck, deck, null)


## Starts the match (its coin toss picks the first player; in a rematch the
## other player goes first), shows who goes first, then lets the driver play.
func _on_start_requested(deck: Deck, level: AILevel.Level, secret_rule: Rule) -> void:
	var is_rematch: bool = _match != null
	if not is_rematch:
		_setup = MatchSetup.against_ai(deck, _ai_deck, level, _rng)
	_match = _setup.rematch(secret_rule) if is_rematch else _setup.start(secret_rule)
	_shown_events = 0
	var view: PublicView = _match.public_view(HUMAN)
	_rules_panel.show_decks(view.decks[AI], view.decks[HUMAN], view.own_secret_rule)
	_board_view.show_board(view.position.board, [], HUMAN, view.position.first_player)
	var player_goes_first: bool = view.position.first_player == HUMAN
	_show_status(TurnPrompt.new("You go first." if player_goes_first else "The AI goes first."))
	await _setup_screen.show_coin_toss(player_goes_first, is_rematch)
	var ai: AIController = AIController.for_level(_setup.ai_level(), _rng)
	ai.think_limit_msec = AIController.HARD_THINK_LIMIT_MSEC
	var controllers: Array[Controller] = [_human, ai]
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


## A tap on a glowing cell places the player's ball there: it flies to the
## cell, as the AI's does. Dragging was unreliable on some touch screens.
## Taps on other cells, or when the player can't place, do nothing.
func _on_cell_pressed(cell: Vector2i) -> void:
	if not _player_ball.draggable or not _is_legal_for_player(cell):
		return
	_player_ball.draggable = false
	_cue.target = null
	await _player_ball.fly_to(_board_view.cell_centre(cell), AI_FLY_SECONDS)
	_human.choose(Command.place(cell))


## The player's own actions return to the live board first, so what they
## cause animates there.
func _on_colour_picked(colour: String) -> void:
	Settings.mark_hint_seen(GameSettings.HINT_COLOUR_PICK)
	_go_live()
	_human.choose(Command.pick_colour(colour))


## Guess names the AI's secret rule outright: right wins, wrong loses.
func _on_guess_requested(rule_id: String) -> void:
	_go_live()
	_human.choose(Command.guess(rule_id))


## On a full board, Seal makes the player's sealed forced guess.
func _on_seal_requested(rule_id: String) -> void:
	_go_live()
	_human.choose(Command.forced_guess(rule_id))


## Back to the setup screen to choose a secret rule for the next match on the
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
		elif event.type == HistoryEntry.Type.COLOUR_PICK:
			EventBus.colour_picked.emit(event.player == HUMAN, event.colour)
		elif event.type == HistoryEntry.Type.GUESS:
			EventBus.guessed.emit(event.player == HUMAN, _match.turn(), event.right)
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
	_show_status(TurnPrompt.new())
	_cue.target = null
	_coach.show_hint("", Vector2.ZERO)
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


## Back reaches here only during a match: the setup and match-end screens and
## the open dialog take it first.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_leave_dialog.open()


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
	_show_status(TurnPrompt.new("A past board.", _history.past_turn_text()))
	_cue.target = null
	_coach.show_hint("", Vector2.ZERO)


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
	_show_status(TurnPrompt.for_view(view))
	if my_placement:
		_cue.target = _player_ball
	elif view.colour_pick_due():
		_cue.target = _picker
	else:
		_cue.target = null
	var hint: String = CoachMark.hint_for(view, Settings)
	_coach.show_hint(hint, HINT_CORNERS.get(hint, Vector2.ZERO))
	if view.phase == Match.Phase.OVER:
		# Reading the AI's placements is hinted through the first match only.
		Settings.mark_hint_seen(GameSettings.HINT_WATCH_AI)
		_rules_panel.show_match_over(view.revealed_secret_rules[AI])
		_match_end.show_summary(MatchEndSummary.from_view(view))


## The prompt beside the board and its detail line.
func _show_status(turn_prompt: TurnPrompt) -> void:
	_status.text = turn_prompt.prompt
	_status_detail.text = turn_prompt.detail
