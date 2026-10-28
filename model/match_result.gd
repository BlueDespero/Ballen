class_name MatchResult
extends RefCounted

## How a match ended. Set by the match when it enters Phase.OVER; null before.
## Treat it as an immutable value.

enum Reason {
	## The loser's third skip.
	THIRD_SKIP,
	## The winner named the loser's true rule.
	RIGHT_GUESS,
	## The loser named a rule that wasn't the winner's true rule.
	WRONG_GUESS,
	## Both forced guesses on a full board; a draw unless exactly one was right.
	FORCED_GUESSES,
}

## The winning player, or Players.NONE for a draw.
var winner: int
var reason: Reason


func _init(p_winner: int, p_reason: Reason) -> void:
	winner = p_winner
	reason = p_reason


func is_draw() -> bool:
	return winner == Players.NONE


func copy() -> MatchResult:
	return MatchResult.new(winner, reason)
