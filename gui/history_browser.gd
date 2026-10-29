class_name HistoryBrowser
extends RefCounted

## The history view's state: which past turn is on show (or the live board),
## stepping turn by turn, and what to say about a past turn. It works on the
## player's view of the match and draws nothing; the match scene shows what it
## says. The view only steps while the match runs and the scene isn't busy
## (animating new events). When the match moves on while a past turn is on
## show, the browser stays on it and notes that the match moved on; a finished
## match goes back to live.

## viewed_turn while the live board is on show.
const LIVE: int = -1

## The past turn on show, or LIVE.
var viewed_turn: int = LIVE
## Whether the match moved on while the past turn was on show.
var moved_on: bool = false
## Set by the scene while it can't let the player browse (new events animating).
var busy: bool = false

## The player's view of the live match; past boards are rebuilt from it.
var live_view: PublicView = null:
	set(view):
		if (viewing_past() and view != null and live_view != null
				and view.position.history.size() > live_view.position.history.size()):
			moved_on = true
		live_view = view
		if view != null and view.phase == Match.Phase.OVER:
			go_live()


## Back to the live board with nothing to view: before a new match.
func reset() -> void:
	live_view = null
	viewed_turn = LIVE
	moved_on = false


func viewing_past() -> bool:
	return viewed_turn != LIVE


## Whether the player may step through past boards now.
func can_browse() -> bool:
	return live_view != null and live_view.phase != Match.Phase.OVER and not busy


## Whether there is an earlier turn to step back to.
func can_go_back() -> bool:
	return can_browse() and (viewed_turn > 1 if viewing_past() else latest_turn() >= 1)


## Back a turn; from the live board, to the latest turn with a placement or
## skip. Whether the view changed.
func step_back() -> bool:
	if not can_go_back():
		return false
	viewed_turn = latest_turn() if not viewing_past() else viewed_turn - 1
	return true


## Forward a turn; past the latest one, back to the live board. Whether the
## view changed.
func step_forward() -> bool:
	if not viewing_past():
		return false
	if viewed_turn < latest_turn():
		viewed_turn += 1
	else:
		go_live()
	return true


## Back to the live board. Whether the view changed.
func go_live() -> bool:
	moved_on = false
	if not viewing_past():
		return false
	viewed_turn = LIVE
	return true


## The latest turn with a placement or skip: the current one once its ball is
## placed or skipped, otherwise the one before.
func latest_turn() -> int:
	var position: MatchPosition = live_view.position
	return position.turn if position.after_turn(position.turn) != null else position.turn - 1


## The position right after the viewed turn's placement or skip, that event
## last in its history.
func past_position() -> MatchPosition:
	return live_view.position.after_turn(viewed_turn)


## Which turn is on show, who made it and what happened, for the viewer.
func past_turn_text() -> String:
	var event: HistoryEntry = past_position().history[-1]
	var by_viewer: bool = event.player == live_view.viewer
	var what: String = tr("you placed %s") if by_viewer else tr("the AI placed %s")
	if event.type == HistoryEntry.Type.SKIP:
		what = tr("you had no legal cell for %s, so the ball was skipped") if by_viewer \
			else tr("the AI had no legal cell for %s, so the ball was skipped")
	return tr("Turn %d of %d: %s.\n\nA past board. Press Live, or play on, to return.") % [
		viewed_turn, latest_turn(), what % BallColour.word(event.colour)]
