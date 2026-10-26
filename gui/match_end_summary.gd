class_name MatchEndSummary
extends RefCounted

## What the match-end screen tells one viewer: win, lose or draw, how the
## match ended, and both true rules. Built from the viewer's PublicView once
## the match is over; the player's opponent is called "the AI".
##
## Guesses are read from the end of the history, so forced guesses on a full
## board must be recorded as GUESS entries, like any other guess.

enum Outcome { WIN, LOSS, DRAW }

var outcome: Outcome
## "You win", "You lose" or "Draw".
var headline: String
## How the match ended, in a sentence or (for forced guesses) three.
var reason: String
## The viewer's true rule.
var own_true_rule: Rule
## The AI's true rule, revealed now the match is over.
var opponent_true_rule: Rule


## The summary for the view's viewer; null while the match runs.
static func from_view(view: PublicView) -> MatchEndSummary:
	if view.result == null:
		return null
	var summary: MatchEndSummary = MatchEndSummary.new()
	summary.own_true_rule = view.revealed_true_rules[view.viewer]
	summary.opponent_true_rule = view.revealed_true_rules[view.opponent()]
	if view.result.is_draw():
		summary.outcome = Outcome.DRAW
		summary.headline = "Draw"
	elif view.result.winner == view.viewer:
		summary.outcome = Outcome.WIN
		summary.headline = "You win"
	else:
		summary.outcome = Outcome.LOSS
		summary.headline = "You lose"
	var sentences: PackedStringArray = []
	match view.result.reason:
		MatchResult.Reason.THIRD_SKIP:
			var skipper_is_viewer: bool = view.result.winner != view.viewer
			sentences.append("%s skipped for the third time." % ("You" if skipper_is_viewer else "The AI"))
		MatchResult.Reason.FORCED_GUESSES:
			sentences.append("The board is full.")
	for guess: HistoryEntry in _closing_guesses(view):
		sentences.append(_guess_sentence(view, guess))
	summary.reason = " ".join(sentences)
	return summary


## The guesses that ended the match, the viewer's first: the history's last
## entries, if they are guesses (one guess, or both forced guesses).
static func _closing_guesses(view: PublicView) -> Array[HistoryEntry]:
	var guesses: Array[HistoryEntry] = []
	var history: Array[HistoryEntry] = view.position.history
	var i: int = history.size() - 1
	while i >= 0 and history[i].type == HistoryEntry.Type.GUESS:
		if history[i].player == view.viewer:
			guesses.push_front(history[i])
		else:
			guesses.push_back(history[i])
		i -= 1
	return guesses


## "You named R04 "Never on the edge", the AI's true rule." and the like.
static func _guess_sentence(view: PublicView, guess: HistoryEntry) -> String:
	var by_viewer: bool = guess.player == view.viewer
	var rule: Rule = view.decks[Players.opponent(guess.player)].rule(guess.rule_id)
	return "%s named %s \"%s\", %s%s true rule." % [
		"You" if by_viewer else "The AI", rule.id, rule.text,
		"" if guess.right else "but it isn't ", "the AI's" if by_viewer else "your"]
