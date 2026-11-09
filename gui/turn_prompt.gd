class_name TurnPrompt
extends RefCounted

## What the status beside the board says, from the player's view: a short
## prompt that starts with what to do, in large text, and a detail line under
## it in smaller text. Players read the prompt and skip the rest, so the prompt
## alone must tell them what to do now; when they could also guess, the detail
## says so, as the second option. Both are empty once the match is over (the
## match-end screen says how it went).

## The prompt: what to do now, or whose turn it is.
var prompt: String = ""
## Why, or what else the player could do.
var detail: String = ""


func _init(p_prompt: String = "", p_detail: String = "") -> void:
	prompt = p_prompt
	detail = p_detail


static func for_view(view: PublicView) -> TurnPrompt:
	var player: int = view.viewer
	if view.phase == Match.Phase.OVER:
		return TurnPrompt.new()
	if view.phase == Match.Phase.FORCED_GUESS:
		return _forced_guess(view)
	var skip: HistoryEntry = _skip_this_turn(view)
	if skip != null:
		if skip.player == player:
			return TurnPrompt.new(_tr("Pick the AI's next colour."),
				_tr("You had no legal cell for %s, so your ball was skipped.") % BallColour.word(skip.colour))
		return TurnPrompt.new(_tr("The AI is thinking…"),
			_tr("The AI had no legal cell for %s, so its ball was skipped.") % BallColour.word(skip.colour))
	if view.current_player != player:
		if view.phase == Match.Phase.FIRST_COLOUR:
			return TurnPrompt.new(_tr("You go first."), _tr("The AI is picking your first colour…"))
		return TurnPrompt.new(_tr("The AI is thinking…"))
	var or_guess: bool = view.can_guess()
	match view.phase:
		Match.Phase.FIRST_COLOUR:
			return TurnPrompt.new(_tr("Pick the AI's first colour."), _tr("The AI goes first."))
		Match.Phase.PLACE:
			return TurnPrompt.new(_tr("Place your ball."), _tr("Tap a glowing cell, or drag your ball onto one. Or select one of the AI's rules and guess it.")
				if or_guess else _tr("Tap a glowing cell, or drag your ball onto one."))
		Match.Phase.PICK_COLOUR:
			return TurnPrompt.new(_tr("Pick the AI's next colour."), _tr("That ends your turn. You can still guess first.")
				if or_guess else _tr("That ends your turn."))
	return TurnPrompt.new()


## The current player's skip, if their turn started with one; null otherwise.
static func _skip_this_turn(view: PublicView) -> HistoryEntry:
	var history: Array[HistoryEntry] = view.position.history
	if view.phase != Match.Phase.PICK_COLOUR or history.is_empty():
		return null
	var last: HistoryEntry = history[-1]
	if last.type == HistoryEntry.Type.SKIP and last.player == view.current_player:
		return last
	return null


## The board is full: whose forced guess is due. A sealed guess is never shown.
static func _forced_guess(view: PublicView) -> TurnPrompt:
	if view.forced_guess_due() and view.can_guess():
		return TurnPrompt.new(_tr("Guess or seal."),
			_tr("The board is full. Guess the AI's secret rule now, or seal your forced guess until both are in."))
	if view.forced_guess_due():
		return TurnPrompt.new(_tr("Seal your guess."),
			_tr("The board is full. Name the AI's secret rule: it stays sealed until both guesses are in."))
	if view.current_player == view.viewer:
		return TurnPrompt.new(_tr("Guess sealed."), _tr("The board is full and your forced guess is sealed. The AI is guessing…"))
	return TurnPrompt.new(_tr("The AI is guessing…"), _tr("The board is full. The AI is making its forced guess…"))


## Static functions have no tr(); the translation server's does the same.
static func _tr(text: String) -> String:
	return TranslationServer.translate(text)
