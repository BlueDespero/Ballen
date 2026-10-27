class_name Deduction
extends RefCounted

## How the AI rules out the opponent's rules, from a PublicView only (ADR 0002).
##
## Ruling out is certain: a candidate is ruled out when one of the opponent's
## placements breaks it, or when the opponent skipped although it would have
## allowed a cell for that colour. Each event is judged on the position as it
## was just before it (board, first player, turn, skips and history), exactly
## as the match judged it, so rules that read history or rows see what the
## real check saw.


## The rules of the opponent's deck not yet ruled out, in deck order.
static func candidates(view: PublicView) -> Array[Rule]:
	var opponent: int = view.opponent()
	var remaining: Array[Rule] = view.decks[opponent].rules.duplicate()
	var history: Array[HistoryEntry] = view.position.history
	for i: int in history.size():
		var event: HistoryEntry = history[i]
		if event.player != opponent or not event.is_placement_or_skip():
			continue
		var before: MatchPosition = view.position.before(i)
		var kept: Array[Rule] = []
		for rule: Rule in remaining:
			if not rules_out(rule, before, event):
				kept.append(rule)
		remaining = kept
	return remaining


## Whether the event proves the rule is not its player's true rule, judged on
## the position just before the event (MatchPosition.before). #58 can pass a
## hypothetical event.
static func rules_out(rule: Rule, before: MatchPosition, event: HistoryEntry) -> bool:
	match event.type:
		HistoryEntry.Type.PLACEMENT:
			return not RuleChecker.is_legal(rule, before, event.player, event.colour, event.cell)
		HistoryEntry.Type.SKIP:
			for cell: Vector2i in before.board.empty_cells():
				if RuleChecker.is_legal(rule, before, event.player, event.colour, cell):
					return true
	return false
