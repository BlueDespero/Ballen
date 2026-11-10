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
	return candidates_for(view, view.opponent())


## The rules of this player's deck their public moves have not ruled out, in
## deck order. For the viewer's own deck, it is what the opponent can know.
static func candidates_for(view: PublicView, player: int) -> Array[Rule]:
	var remaining: Array[Rule] = view.decks[player].rules.duplicate()
	var history: Array[HistoryEntry] = view.position.history
	for i: int in history.size():
		var event: HistoryEntry = history[i]
		if event.player != player or not event.is_placement_or_skip():
			continue
		var before: MatchPosition = view.position.before(i)
		var kept: Array[Rule] = []
		for rule: Rule in remaining:
			if not rules_out(rule, before, event):
				kept.append(rule)
		remaining = kept
	return remaining


## Whether the event proves the rule is not its player's secret rule, judged on
## the position just before the event (MatchPosition.before). #58 can pass a
## hypothetical event.
static func rules_out(rule: Rule, before: MatchPosition, event: HistoryEntry) -> bool:
	match event.type:
		HistoryEntry.Type.PLACEMENT:
			return not RuleChecker.is_legal(rule, before, event.player, event.colour, event.cell)
		HistoryEntry.Type.SKIP:
			return RuleChecker.legal_mask(rule, before, event.player, event.colour) != 0
	return false
