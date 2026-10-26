class_name Deduction
extends RefCounted

## How the AI rules out the opponent's rules, from a PublicView only (ADR 0002).
##
## Hard elimination: a candidate is ruled out when one of the opponent's
## placements breaks it. Each event is judged on the position as it was just
## before it (board, first player, turn, skips and history), exactly as the
## match judged it, so rules that read history or rows see what the real
## check saw.


## The rules of the opponent's deck not yet ruled out, in deck order.
static func candidates(view: PublicView) -> Array[Rule]:
	var opponent: int = view.opponent()
	var remaining: Array[Rule] = view.decks[opponent].rules.duplicate()
	var history: Array[HistoryEntry] = view.position.history
	for i: int in history.size():
		var event: HistoryEntry = history[i]
		if event.player != opponent or event.type != HistoryEntry.Type.PLACEMENT:
			continue
		var before: MatchPosition = position_before(view.position, i)
		var kept: Array[Rule] = []
		for rule: Rule in remaining:
			if not rules_out(rule, before, event):
				kept.append(rule)
		remaining = kept
	return remaining


## Whether the event proves the rule is not its player's true rule, judged on
## the position just before the event. #58 can pass a hypothetical event.
static func rules_out(rule: Rule, before: MatchPosition, event: HistoryEntry) -> bool:
	if event.type == HistoryEntry.Type.PLACEMENT:
		return not RuleChecker.is_legal(rule, before, event.player, event.colour, event.cell)
	return false


## The position just before the placement at history[index]: every later
## placement taken off the board, later colour picks and skips undone, history
## cut before it. Its colour is the event's colour.
static func position_before(position: MatchPosition, index: int) -> MatchPosition:
	var history: Array[HistoryEntry] = position.history
	var later_cells: Array[Vector2i] = []
	var later_picks: int = 0
	var later_skips: Array[int] = [0, 0]
	for i: int in range(index, history.size()):
		var event: HistoryEntry = history[i]
		match event.type:
			HistoryEntry.Type.PLACEMENT:
				later_cells.append(event.cell)
			HistoryEntry.Type.COLOUR_PICK:
				later_picks += 1
			HistoryEntry.Type.SKIP:
				later_skips[event.player] += 1
	var board: Board = Board.new()
	for cell: Vector2i in Board.all_cells():
		var ball: Ball = position.board.ball_at(cell)
		if ball != null and not later_cells.has(cell):
			board.place(cell, ball)
	var before: MatchPosition = MatchPosition.from_board(board, position.first_player)
	before.turn = position.turn - later_picks
	before.colour = history[index].colour
	for player: int in Players.COUNT:
		before.skips[player] = position.skips[player] - later_skips[player]
	before.history = history.slice(0, index)
	return before
